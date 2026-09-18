//
//  espkrw.m
//  DarkSword
//
//  Kernel bridge replacing CrackTeam's TrollStore task_for_pid path.
//  See espkrw.h for the design notes.
//
//  Port-transplant technique (offset-free where possible):
//    - allocate a mach port in our own task + make a send right
//    - locate its ipc_port in the kernel via the existing
//      task_get_ipc_port_table_entry() helper (works on iOS 17/18 per
//      kutils.m notes: verified on SE3/18.6.2)
//    - copy io_bits from OUR OWN task port (so the IKOT type value is
//      read from the running kernel, not hardcoded), then overwrite the
//      type with IKOT_TASK and set ip_kobject to the game task address
//      (offset off_ipc_port_ip_kobject from offsets.m: 0x48 on 18.x)
//    - result: a regular mach send right that the kernel treats as the
//      game's task control port -> mach_vm_read_overwrite/mach_vm_write/
//      task_info all behave like the TrollStore build
//
//  Cleanup writes back IO_ACTIVE|IKOT_NONE and a NULL kobject, so the
//  borrowed task reference is dropped from the port before anything can
//  release it (no refcount underflow on game exit).
//

#import "espkrw.h"

#import <Foundation/Foundation.h>
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/krw.h"
#import "../kexploit/kutils.h"
#import "../kexploit/offsets.h"
#import "../kexploit/sandbox_escape.h"
#import "../kexploit/persistence.h"

#import <sys/sysctl.h>
#import <errno.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <time.h>
#import <mach/mach.h>

// XNU pid_for_task — dùng làm cổng verify sau transplant (chạy toàn bộ
// đường convert_port_to_task của kernel, bắt port chết/garbage một cách
// an toàn trước khi pipeline tin tưởng dùng port).
extern kern_return_t pid_for_task(task_t task, int *pid);

// XNU ipc_object.h — stable for a decade:
#define ESP_IO_ACTIVE 0x80000000u
#define ESP_IKOT_TASK 2u

static mach_port_t g_espGamePort = MACH_PORT_NULL;
static pid_t       g_espGamePid  = -1;
static uint64_t    g_espGameTaskKaddr = 0;
static uint64_t    g_espGameProcKaddr = 0;
static uint64_t    g_espSelfTaskKaddr = 0;
static uint64_t    g_espGamePortKaddr = 0;
static bool        g_espRootTried     = false;

// PANIC-FIX (audit 2026-09): port dùng LẠI qua các chu kỳ init/stop.
// Trước đây mỗi esp_krw_init cấp phát port mới; heal-loop của ESPEngine
// gọi reinit mỗi 2s khi bridge fail → rò rỉ 1 port + 2 right mỗi lần
// (receive right không bao giờ được huỷ vì ta mất tên port). Giữ tên port
// lại ở đây và transplant đè lên port cũ (đã được stop trả về IKOT_NONE)
// → số port cố định = 1 dù heal bao nhiêu lần.
static mach_port_t g_espReusablePort = MACH_PORT_NULL;

static void esp_destroy_port_rights(mach_port_t port) {
    if (port == MACH_PORT_NULL) return;
    // Huỷ send right rồi receive right — port bị phá huỷ khi right cuối
    // biến mất. Best-effort: lỗi bị bỏ qua (port có thể đã chết).
    mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_SEND, -1);
    mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_RECEIVE, -1);
}

#define ESPKRW_LOG(fmt, ...) printf("[ESPKRW] " fmt "\n", ##__VA_ARGS__)

#pragma mark - Game discovery (TrollStore sysctl logic, verbatim behavior)

// CrackTeam/esp/Core/pid.mm GetGameProcesspid — sysctl KERN_PROC_ALL + p_comm
// strstr. Kept identical: this is the proven "cách tìm game" from the
// TrollStore build.
static pid_t esp_find_game_pid_sysctl(const char *gameName) {
    size_t length = 0;
    static const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    int err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
    if (err == -1) err = errno;
    if (err != 0) return -1;

    struct kinfo_proc *procBuffer = (struct kinfo_proc *)malloc(length);
    if (!procBuffer) return -1;

    err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, procBuffer, &length, NULL, 0);
    if (err == -1) {
        free(procBuffer);
        return -1;
    }

    int count = (int)(length / sizeof(struct kinfo_proc));
    for (int i = 0; i < count; i++) {
        const char *procname = procBuffer[i].kp_proc.p_comm;
        if (strstr(procname, gameName)) {
            pid_t pid = procBuffer[i].kp_proc.p_pid;
            free(procBuffer);
            return pid;
        }
    }
    free(procBuffer);
    return -1;
}

// Kernel-side fallback: proc_find_by_name + off_proc_p_pid.
static pid_t esp_find_game_pid_kernel(const char *gameName) {
    uint64_t proc = proc_find_by_name(gameName);
    if (!proc) return -1;
    uint32_t pid = kread32(proc + off_proc_p_pid);
    if (!pid) return -1;
    return (pid_t)pid;
}

// FIX 2026-09-19 (LIVELOCK — lỗi thật trên máy user): luồng autoStart chạy
// probe → kernel walk THẤY game (set lastWalk=T) → gọi esp_krw_init() NGAY
// tại T+ε → init hỏi lại chính finder có throttle → dính cửa sổ throttle
// 1s → trả -1 → esp_krw_init -3 "KHÔNG thấy tiến trình FreeFire" LẶP VÔ
// HẠN dù game đang chạy (log user: hàng loạt cặp "kernel R/W sẵn sàng" +
// "KHÔNG thấy tiến trình FreeFire" liên tiếp). Probe của monitor 2s cũng
// dính throttle chéo của probe autoStart → gameProcessAlive nhấp nháy đỏ
// → hàng "Game đang chạy" mất. Giờ:
//   • Throttle window trả về CACHE tươi (<5s) thay vì -1 cứng đầu
//   • Pipeline dùng esp_find_game_pid_now() — KHÔNG bao giờ bị throttle
static pid_t g_findCachePid = -1;
static struct timespec g_findCacheAt = {0, 0};
static struct timespec g_lastKernelWalk = {0, 0};

static long esp_ms_since(struct timespec then, struct timespec now) {
    return (now.tv_sec - then.tv_sec) * 1000L
         + (now.tv_nsec - then.tv_nsec) / 1000000L;
}

static void esp_find_cache_store(pid_t pid) {
    g_findCachePid = pid;
    clock_gettime(CLOCK_MONOTONIC, &g_findCacheAt);
}

// Finder cho PIPELINE (esp_krw_init): trả kết quả THỜI ĐIỂM HIỆN TẠI, không
// bao giờ bị cửa sổ throttle đánh lừa thành "không thấy game". Dùng lại
// cache nếu tươi <2s (tiết kiệm 1 walk khi probe vừa chạy ngay trước đó —
// đúng kịch bản probe→init của autoStart), ngược lại sysctl → kernel walk.
static pid_t esp_find_game_pid_now(const char *gameName) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (g_findCachePid != -1 && esp_ms_since(g_findCacheAt, now) < 2000)
        return g_findCachePid;

    pid_t pid = esp_find_game_pid_sysctl(gameName);
    if (pid == -1) pid = esp_find_game_pid_kernel(gameName);
    if (pid != -1) esp_find_cache_store(pid);
    return pid;
}

// Finder cho PROBE định kỳ (monitor 2s / snapshot / alive-check): kernel
// walk tối đa 1 lần/giây (PANIC-FIX giữ nguyên), nhưng trong cửa sổ throttle
// trả CACHE tươi (<5s) thay vì -1 — hết cảnh "vừa thấy game lại báo mất".
pid_t esp_krw_find_game_pid(const char *gameName) {
    pid_t pid = esp_find_game_pid_sysctl(gameName);
    if (pid != -1) {
        esp_find_cache_store(pid);
        return pid;
    }

    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    long elapsedMs = esp_ms_since(g_lastKernelWalk, now);
    if (elapsedMs < 1000) {
        // Trong cửa sổ throttle: cache tươi (<5s) thì dùng — KHÔNG trả -1
        // khi lần walk trước vừa thấy game (đây chính là livelock cũ).
        if (g_findCachePid != -1 && esp_ms_since(g_findCacheAt, now) < 5000)
            return g_findCachePid;
        return -1;
    }
    g_lastKernelWalk = now;
    pid = esp_find_game_pid_kernel(gameName);
    // Cache cả -1: game thật sự vắng thì các probe trong 5s không phải
    // walk lại; game xuất hiện thì walk kế tiếp (≥1s) sẽ thấy ngay.
    esp_find_cache_store(pid);
    return pid;
}

#pragma mark - Port transplant

static kern_return_t esp_transplant_task_port(uint64_t gameTaskKaddr, mach_port_t *outPort) {
    if (!gameTaskKaddr || !g_espSelfTaskKaddr || !is_kaddr_valid(gameTaskKaddr))
        return KERN_INVALID_ARGUMENT;

    kern_return_t kr;
    mach_port_t port = MACH_PORT_NULL;
    bool reused = false;

    // PANIC-FIX: tái sử dụng port đã park từ chu kỳ trước thay vì cấp phát
    // mới (chặn rò rỉ port khi heal-loop chạy liên tục).
    if (g_espReusablePort != MACH_PORT_NULL) {
        port = g_espReusablePort;
        g_espReusablePort = MACH_PORT_NULL;
        reused = true;
    } else {
        kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
        if (kr != KERN_SUCCESS) {
            ESPKRW_LOG("mach_port_allocate thất bại: 0x%x (%s)", kr, mach_error_string(kr));
            return kr;
        }

        kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
        if (kr != KERN_SUCCESS) {
            ESPKRW_LOG("mach_port_insert_right thất bại: 0x%x (%s)", kr, mach_error_string(kr));
            esp_destroy_port_rights(port);
            return kr;
        }
    }

    // Locate the port's ipc_port in kernel space.
    uint64_t portKaddr = task_get_ipc_port_table_entry(g_espSelfTaskKaddr, port);
    if (!portKaddr) {
        ESPKRW_LOG("không tìm được ipc_entry của port (task=0x%llx port=0x%x reused=%d)",
                   g_espSelfTaskKaddr, port, reused);
        esp_destroy_port_rights(port);
        return KERN_FAILURE;
    }

    // Read the type word of our own task port so the IKOT_TASK value and the
    // IO_ACTIVE bit match the running kernel exactly.
    uint64_t selfTaskPortKaddr = task_get_ipc_port_table_entry(g_espSelfTaskKaddr, mach_task_self());
    if (!selfTaskPortKaddr) {
        ESPKRW_LOG("không tìm được ipc_entry của task port của chính mình");
        esp_destroy_port_rights(port);
        return KERN_FAILURE;
    }
    uint32_t selfBits = kread32(selfTaskPortKaddr);
    uint32_t newBits  = (selfBits & ESP_IO_ACTIVE) | ESP_IKOT_TASK;
    if (!(newBits & ESP_IO_ACTIVE)) newBits |= ESP_IO_ACTIVE;

    // Snapshot the entry's ORIGINAL values so the rollback below restores
    // exactly what was there before (writing generic cleanup values over an
    // entry that belongs to an unrelated port would corrupt it).
    uint32_t origBits = kread32(portKaddr);
    uint64_t origKobject = kread64(portKaddr + off_ipc_port_ip_kobject);

    // Transplant: type -> IKOT_TASK, kobject -> game task.
    // PANIC-FIX: verify read-back NGAY sau mỗi lần ghi (Task 20 pattern) —
    // ghi hụt mà không biết là mồi mìn cho mọi Mach call sau này.
    kwrite32(portKaddr, newBits);
    if (kread32(portKaddr) != newBits) {
        ESPKRW_LOG("ghi io_bits không verify được — hoàn tác (bits=0x%08x kobject=0x%llx)",
                   origBits, origKobject);
        kwrite32(portKaddr, origBits);
        esp_destroy_port_rights(port);
        return KERN_FAILURE;
    }
    kwrite64(portKaddr + off_ipc_port_ip_kobject, gameTaskKaddr);
    if (kread64(portKaddr + off_ipc_port_ip_kobject) != gameTaskKaddr) {
        ESPKRW_LOG("ghi ip_kobject không verify được — hoàn tác về IKOT_NONE an toàn");
        kwrite32(portKaddr, ESP_IO_ACTIVE);
        kwrite64(portKaddr + off_ipc_port_ip_kobject, 0);
        esp_destroy_port_rights(port);
        return KERN_FAILURE;
    }

    // Verify through the same helper path the kernel will use later.
    uint64_t check = task_get_ipc_port_kobject(g_espSelfTaskKaddr, port);
    if (check != gameTaskKaddr) {
        ESPKRW_LOG("verify kobject thất bại (read=0x%llx expect=0x%llx) — hoàn tác giá trị gốc (bits=0x%08x kobject=0x%llx)",
                   check, gameTaskKaddr, origBits, origKobject);
        kwrite32(portKaddr, origBits);
        kwrite64(portKaddr + off_ipc_port_ip_kobject, origKobject);
        esp_destroy_port_rights(port);
        return KERN_FAILURE;
    }

    *outPort = port;
    g_espGamePortKaddr = portKaddr;
    ESPKRW_LOG("transplant OK: port=0x%x port_kaddr=0x%llx game_task=0x%llx (io_bits=0x%08x reused=%d)",
               port, portKaddr, gameTaskKaddr, newBits, reused);
    return KERN_SUCCESS;
}

#pragma mark - Public API

int esp_krw_init(void) {
    if (g_espGamePort != MACH_PORT_NULL && esp_krw_game_alive()) {
        ESPKRW_LOG("bridge đã sẵn sàng (pid=%d) — dùng lại", g_espGamePid);
        return 0;
    }
    if (g_espGamePort != MACH_PORT_NULL) {
        ESPKRW_LOG("game đã thoát khỏi bridge cũ — dựng lại");
        esp_krw_stop();
    }

    // Step 1: kernel R/W
    if (!kexploit_krw_ready() && !krw_persistence_is_recovered()) {
        ESPKRW_LOG("CHƯA có kernel R/W — hãy bấm Start Darksword trước");
        return -1;
    }
    ESPKRW_LOG("kernel R/W sẵn sàng");

    // Step 2: sandbox escape + root — iOS 26+ ONLY. sandbox_escape.m and
    // sandbox_elevate_to_root target FilzaSlop's iOS 26 struct layout: on
    // iOS 17/18 the chain walk reads garbage and issues blind kernel writes
    // (which is what killed the socket primitive right after Start Darksword
    // on 18.5), and sandbox_elevate_to_root writes self_proc+0x10 — the
    // self->task field on iOS 18 — a guaranteed kernel panic. The ESP bridge
    // only needs kernel R/W (sysctl + port transplant), so skip both below
    // iOS 26 entirely.
    if (!g_espRootTried) {
        g_espRootTried = true;
        NSOperatingSystemVersion espOsv =
            [[NSProcessInfo processInfo] operatingSystemVersion];
        if (espOsv.majorVersion >= 26) {
            uint64_t selfProc = proc_self();
            if (selfProc) {
                if (!sandbox_access_is_active()) {
                    int sbx = sandbox_escape(selfProc);
                    ESPKRW_LOG("sandbox_escape -> %d", sbx);
                }
                int root = sandbox_elevate_to_root(selfProc);
                ESPKRW_LOG("sandbox_elevate_to_root -> %d (uid=%d)", root, getuid());
            } else {
                ESPKRW_LOG("proc_self() = 0 — bỏ qua bước root");
            }
        } else {
            ESPKRW_LOG("iOS %ld — bỏ qua sandbox escape/root (kernel R/W là đủ)",
                       (long)espOsv.majorVersion);
        }
    }

    g_espSelfTaskKaddr = proc_task(proc_self());
    if (!g_espSelfTaskKaddr) {
        ESPKRW_LOG("proc_task(proc_self()) = 0");
        return -2;
    }

    // Step 3: find the game (HYBRID: sysctl trước — TrollStore logic, kernel
    // proc_find_by_name fallback — Task 18: sysctl-only bị sandbox chặn trên
    // iOS 18 nên trước đây pipeline không bao giờ thấy game)
    // FIX 2026-09-19 (LIVELOCK): DÙNG esp_find_game_pid_now — bản cũ gọi
    // esp_krw_find_game_pid (có throttle 1s) trong khi probe của autoStart
    // VỪA walk xong vài chục ms trước → init luôn dính throttle → -1 →
    // -3 lặp vô hạn dù game đang chạy (log: "KHÔNG thấy tiến trình
    // FreeFire" lặp liên tục). esp_find_game_pid_now không bao giờ bị
    // throttle đánh lừa và tái dùng cache tươi <2s nên không tốn thêm walk.
    pid_t pid = esp_find_game_pid_now("FreeFire");
    if (pid == -1) {
        ESPKRW_LOG("KHÔNG thấy tiến trình FreeFire — hãy mở game trước khi bật ESP");
        return -3;
    }
    g_espGamePid = pid;
    ESPKRW_LOG("tìm thấy FreeFire pid=%d", pid);

    // Step 4: kernel proc/task addresses
    uint64_t proc = proc_find_by_name("FreeFire");
    if (!proc) proc = proc_find(pid);
    if (!proc) {
        ESPKRW_LOG("proc_find(%d) = 0", pid);
        return -4;
    }
    g_espGameProcKaddr = proc;

    // PANIC-FIX (audit 2026-09): chặn race game-thoát-giữa-chừng trước khi
    // ghi task kaddr vào port — 2 lần đọc task phải khớp nhau, pid phải
    // còn đúng, kaddr phải nằm trong vùng kernel hợp lệ.
    uint64_t task1 = proc_task(proc);
    uint32_t pidRecheck = kread32(proc + off_proc_p_pid);
    uint64_t task2 = proc_task(proc);
    if (!task1 || task1 != task2 || !is_kaddr_valid(task1)) {
        ESPKRW_LOG("proc_task(proc=0x%llx) không ổn định/invalid (t1=0x%llx t2=0x%llx)",
                   proc, task1, task2);
        return -5;
    }
    if (pidRecheck != (uint32_t)pid) {
        ESPKRW_LOG("game vừa thoát trong lúc dựng bridge (pid %d -> %u) — thử lần sau", pid, pidRecheck);
        return -4;
    }
    uint64_t task = task1;
    g_espGameTaskKaddr = task;
    ESPKRW_LOG("game proc=0x%llx task=0x%llx", proc, task);

    // Step 5: transplant + verify
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = esp_transplant_task_port(task, &port);
    if (kr != KERN_SUCCESS) {
        (void)kr;
        return -6;
    }

    // PANIC-FIX: cổng chức năng cuối — pid_for_task chạy đúng đường
    // convert_port_to_task mà mọi Mach call sau này sẽ đi. Port chết /
    // sai task bị bắt ở đây thay vì để pipeline dùng port rác.
    int gatePid = -1;
    if (pid_for_task(port, &gatePid) != KERN_SUCCESS || gatePid != pid) {
        ESPKRW_LOG("pid_for_task qua port không khớp (got=%d expect=%d) — hoàn tác", gatePid, pid);
        g_espGamePort = port;          // cho stop() biết port cần hoàn tác
        esp_krw_stop();
        return -7;
    }

    g_espGamePort = port;

    ESPKRW_LOG("===== ESP kernel bridge HOÀN TẤT (pid=%d) =====", g_espGamePid);
    return 0;
}

int esp_krw_reinit(void) {
    esp_krw_stop();
    return esp_krw_init();
}

void esp_krw_stop(void) {
    if (g_espGamePortKaddr) {
        // PANIC-FIX (Task 20 pattern — verify read-back): KHÔNG ghi mù vào
        // kernel. Đọc trạng thái hiện tại trước:
        //   • kobject đã 0 và bits đã là plain port → đã restored, bỏ qua.
        //   • kobject KHÁC với task ta đã ghi → kernel state đã đổi, KHÔNG
        //     đụng vào (ghi mù vào entry lạ = kernel panic).
        uint32_t curBits  = kread32(g_espGamePortKaddr);
        uint64_t curKobj  = kread64(g_espGamePortKaddr + off_ipc_port_ip_kobject);
        if (curKobj == 0 && curBits != 0 && !(curBits & ~ESP_IO_ACTIVE)) {
            ESPKRW_LOG("port 0x%x đã ở trạng thái restored — bỏ qua ghi", g_espGamePort);
        } else if (curKobj != g_espGameTaskKaddr) {
            ESPKRW_LOG("port kaddr 0x%llx KHÔNG còn do ta kiểm soát (kobj=0x%llx task=0x%llx) — không ghi mù",
                       g_espGamePortKaddr, curKobj, g_espGameTaskKaddr);
        } else {
            // Restore to a plain active receive port; drop the claimed task
            // reference so nothing (including process exit) can underflow it.
            kwrite32(g_espGamePortKaddr, ESP_IO_ACTIVE);   // IO_ACTIVE | IKOT_NONE
            kwrite64(g_espGamePortKaddr + off_ipc_port_ip_kobject, 0);
            uint32_t vb = kread32(g_espGamePortKaddr);
            uint64_t vk = kread64(g_espGamePortKaddr + off_ipc_port_ip_kobject);
            if (vb != ESP_IO_ACTIVE || vk != 0)
                ESPKRW_LOG("CẢNH BÁO: restore không verify được (bits=0x%08x kobj=0x%llx)", vb, vk);
            else
                ESPKRW_LOG("port 0x%x đã hoàn tác về IKOT_NONE (verify OK)", g_espGamePort);
        }
    }
    // PANIC-FIX (leak): park port để chu kỳ init kế tiếp tái sử dụng thay
    // vì cấp phát mới. Nếu đã có port parked thì phá huỷ port thừa.
    if (g_espGamePort != MACH_PORT_NULL) {
        if (g_espReusablePort == MACH_PORT_NULL) {
            g_espReusablePort = g_espGamePort;
        } else {
            esp_destroy_port_rights(g_espGamePort);
        }
    }
    g_espGamePort = MACH_PORT_NULL;
    g_espGamePortKaddr = 0;
    g_espGameTaskKaddr = 0;
    g_espGameProcKaddr = 0;
    g_espGamePid = -1;
}

mach_port_t esp_krw_task_port(void) {
    return g_espGamePort;
}

pid_t esp_krw_game_pid(void) {
    return g_espGamePid;
}

uint64_t esp_krw_game_task_kaddr(void) {
    return g_espGameTaskKaddr;
}

uint64_t esp_krw_game_proc_kaddr(void) {
    return g_espGameProcKaddr;
}

bool esp_krw_game_alive(void) {
    if (g_espGamePid <= 0) return false;
    // FIX 2026-09-19 (livelock): dùng finder có throttle+cache — bản cũ
    // proc_find_by_name TRỰC TIẾP nghĩa là MỖI lần esp_krw_ready() (monitor
    // 2s + snapshot + heal gate + init fast-path) đều quét toàn bộ proc-list
    // — đúng thứ throttle của finder muốn tránh. Ngữ nghĩa giữ nguyên: proc
    // tìm thấy theo tên phải có pid trùng pid đã ghim (chống pid reuse).
    pid_t pid = esp_krw_find_game_pid("FreeFire");
    return pid != -1 && pid == (pid_t)g_espGamePid;
}

bool esp_krw_ready(void) {
    return g_espGamePort != MACH_PORT_NULL && esp_krw_game_alive();
}

bool esp_krw_game_process_exists(void) {
    return esp_krw_find_game_pid("FreeFire") != -1;
}

// Sysctl-ONLY probe — never touches kernel R/W primitives, so it is safe in
// every state including before Start Darksword. Used by the ESP status UI
// snapshot (ESPEngine.collectStatusSnapshot) so opening the ESP tab can show
// honest green/red rows without performing a single kernel read.
bool esp_krw_game_process_exists_sysctl(void) {
    return esp_find_game_pid_sysctl("FreeFire") != -1;
}

// HYBRID probe (esp_krw_find_game_pid) + pipeline finder
// (esp_find_game_pid_now): định nghĩa ở ĐẦU file, ngay sau
// esp_find_game_pid_kernel — cần trước esp_krw_init (use-before-decl).
