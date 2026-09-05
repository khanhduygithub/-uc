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

#pragma mark - Port transplant

static kern_return_t esp_transplant_task_port(uint64_t gameTaskKaddr, mach_port_t *outPort) {
    if (!gameTaskKaddr || !g_espSelfTaskKaddr) return KERN_INVALID_ARGUMENT;

    kern_return_t kr;
    mach_port_t port = MACH_PORT_NULL;

    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) {
        ESPKRW_LOG("mach_port_allocate thất bại: 0x%x (%s)", kr, mach_error_string(kr));
        return kr;
    }

    kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        ESPKRW_LOG("mach_port_insert_right thất bại: 0x%x (%s)", kr, mach_error_string(kr));
        mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_RECEIVE, -1);
        return kr;
    }

    // Locate the new port's ipc_port in kernel space.
    uint64_t portKaddr = task_get_ipc_port_table_entry(g_espSelfTaskKaddr, port);
    if (!portKaddr) {
        ESPKRW_LOG("không tìm được ipc_entry của port mới (task=0x%llx port=0x%x)",
                   g_espSelfTaskKaddr, port);
        return KERN_FAILURE;
    }

    // Read the type word of our own task port so the IKOT_TASK value and the
    // IO_ACTIVE bit match the running kernel exactly.
    uint64_t selfTaskPortKaddr = task_get_ipc_port_table_entry(g_espSelfTaskKaddr, mach_task_self());
    if (!selfTaskPortKaddr) {
        ESPKRW_LOG("không tìm được ipc_entry của task port của chính mình");
        return KERN_FAILURE;
    }
    uint32_t selfBits = kread32(selfTaskPortKaddr);
    uint32_t newBits  = (selfBits & ESP_IO_ACTIVE) | ESP_IKOT_TASK;
    if (!(newBits & ESP_IO_ACTIVE)) newBits |= ESP_IO_ACTIVE;

    // Transplant: type -> IKOT_TASK, kobject -> game task.
    kwrite32(portKaddr, newBits);
    kwrite64(portKaddr + off_ipc_port_ip_kobject, gameTaskKaddr);

    // Verify through the same helper path the kernel will use later.
    uint64_t check = task_get_ipc_port_kobject(g_espSelfTaskKaddr, port);
    if (check != gameTaskKaddr) {
        ESPKRW_LOG("verify kobject thất bại (read=0x%llx expect=0x%llx) — hoàn tác",
                   check, gameTaskKaddr);
        kwrite32(portKaddr, ESP_IO_ACTIVE);          // IO_ACTIVE | IKOT_NONE
        kwrite64(portKaddr + off_ipc_port_ip_kobject, 0);
        return KERN_FAILURE;
    }

    *outPort = port;
    g_espGamePortKaddr = portKaddr;
    ESPKRW_LOG("transplant OK: port=0x%x port_kaddr=0x%llx game_task=0x%llx (io_bits=0x%08x)",
               port, portKaddr, gameTaskKaddr, newBits);
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

    // Step 3: find the game (sysctl first — TrollStore logic, kernel fallback)
    pid_t pid = esp_find_game_pid_sysctl("FreeFire");
    if (pid == -1) pid = esp_find_game_pid_kernel("FreeFire");
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
    uint64_t task = proc_task(proc);
    if (!task) {
        ESPKRW_LOG("proc_task(proc=0x%llx) = 0", proc);
        return -5;
    }
    g_espGameTaskKaddr = task;
    ESPKRW_LOG("game proc=0x%llx task=0x%llx", proc, task);

    // Step 5: transplant + verify
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = esp_transplant_task_port(task, &port);
    if (kr != KERN_SUCCESS) {
        (void)kr;
        return -6;
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
        // Restore to a plain active receive port; drop the claimed task
        // reference so nothing (including process exit) can underflow it.
        kwrite32(g_espGamePortKaddr, ESP_IO_ACTIVE);   // IO_ACTIVE | IKOT_NONE
        kwrite64(g_espGamePortKaddr + off_ipc_port_ip_kobject, 0);
        ESPKRW_LOG("port 0x%x đã hoàn tác về IKOT_NONE (không deallocate — tránh rò rỉ ref task)",
                   g_espGamePort);
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
    // Kernel-side check: the proc must still be findable AND the pid must
    // still match (pid reuse protection).
    uint64_t proc = proc_find_by_name("FreeFire");
    if (!proc) return false;
    uint32_t pid = kread32(proc + off_proc_p_pid);
    return pid == (uint32_t)g_espGamePid;
}

bool esp_krw_ready(void) {
    return g_espGamePort != MACH_PORT_NULL && esp_krw_game_alive();
}

bool esp_krw_game_process_exists(void) {
    pid_t pid = esp_find_game_pid_sysctl("FreeFire");
    if (pid == -1) pid = esp_find_game_pid_kernel("FreeFire");
    return pid != -1;
}

// Sysctl-ONLY probe — never touches kernel R/W primitives, so it is safe in
// every state including before Start Darksword. Used by the ESP status UI
// snapshot (ESPEngine.collectStatusSnapshot) so opening the ESP tab can show
// honest green/red rows without performing a single kernel read.
bool esp_krw_game_process_exists_sysctl(void) {
    return esp_find_game_pid_sysctl("FreeFire") != -1;
}
