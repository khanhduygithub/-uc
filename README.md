# excalibur

excalibur is a project that use DarkSword exploit for customize your iPhone, include some feature like Springboard injection, bypass 3 app limit, etc.

## 🆕 Excalibur ESP (ported from Vip.zip — DarkSword edition)

Toàn bộ pipeline ESP của Vip.zip (FFExternal) đã được remake để chạy bằng
**DarkSword kernel exploit** — KHÔNG còn phụ thuộc TrollStore:

| Vip.zip (TrollStore) | Excalibur (DarkSword) |
|---|---|
| `task_for_pid` nhờ entitlements | `task_for_pid` nhờ kernel patch (rootify + AMFI label = 0 + sandbox label = 0) |
| Theos `.tipa` app | Xcode app (kfun) |
| ModMenu (floating) | Tab UI: **Start ESP** + **Cấu hình** |

### Cấu trúc mới

```
ESP/
  DSProcessBridge.h/.m   ← lõi: kernel exploit → rootify/AMFI/sandbox → task port → r/w
  GameOffsets.h          ← offset game (cập nhật khi game update)
  GameLogic.h/.m         ← chuỗi Unity: match → players → bones → W2S
  ESPDrawingView.h/.m    ← CAShapeLayer overlay 60fps (box/bone/line/hp/name/dis)
  ESPManager.h/.m        ← điều phối start/stop + overlay window
  FloatingMenuView.h/.m  ← nút trôi nổi trên game (tap = mở config, giữ = kéo)
  ESPPrefs.h/.m          ← lưu cấu hình
MainUI/
  MainTabController.h/.m ← 2 tab
  StartESPViewController ← tab 1: log + nút kernel/start/stop
  ConfigViewController   ← tab 2: mọi switch chức năng
Tweaks/
  LegacyTweaks.h/.m      ← dock 5 icon + ẩn nhãn icon (giữ từ bản cũ)
```

### Cách dùng

1. Bấm **"1️⃣ Khởi động Kernel"** → DarkSword exploit + rootify + vá AMFI/sandbox
2. Mở game, quay lại app bấm **"▶️ START ESP"**
3. ESP overlay phủ lên game — nút tròn góc trái: tap = cấu hình, kéo = di chuyển
4. Tab **Cấu hình**: bật/tắt Box, Line, Name, Health, Distance, Bone, Count, Bot ESP…;
   đổi tên tiến trình/module game; chạy tweaks cũ (dock 5 icon, ẩn nhãn)

### Đã xoá (theo yêu cầu)

- ❌ `status_bar_tweak()` — đồng hồ status bar "HH:mm - E d/M/yyyy"
- ❌ `StatusBarTweak.m` (dylib + shell script build)
- ❌ `ViewController.m` cũ (thay bằng MainUI) — log tab vẫn giữ trong tab Start ESP

# TODO list
- Springboard inject tweak
- 3 app bypass
- Decrypt app to iPA
- Enable JIT(?)
- Custom mobilegestalt (for Dynamic island enabler, hidden feature, etc)
- Memory finder and editor?

# Credit
- wh1te4ever for kfun-darksword project
- Vip.zip (FFExternal) for the ESP pipeline idea — rebuilt on DarkSword

## 🔎 CI build fix — trạng thái run 15→17 (2026-09-19)

⚠️ **Run 16 & 17 fail vì repo GitHub vẫn giữ file CŨ**: 2 run báo lỗi Y HỆT nhau
(cùng số dòng 353/365/413) trong `ESP/DSProcessBridge.m` → file này CHƯA được
thay bằng bản fix khi push. Khi push zip này lên repo, phải đảm bảo file dưới
đây bị **replace** (không bị bỏ sót):

```
darksword-kexploit-fun/ESP/DSProcessBridge.m   ← 620 dòng (bản runtime fix 3, 2026-09-19 15:00)
```

**Kiểm tra nhanh trên github.com** — mở `darksword-kexploit-fun/ESP/DSProcessBridge.m`:

| Dòng | Bản ĐÚNG (zip này — fix 3) | Bản cũ hơn |
|---|---|---|
| 29 | `#import "GameOffsets.h"` | `#import "../kexploit/kexploit_opa334.h"` (bản build fail) |
| 57 | `#pragma mark - ucred layout (TỰ DÒ — không tin cứng offset theo version)` | `#pragma mark - ucred layout (arm64, xnu-11215 / xnu-11417)` |
| 141 | `static bool dsb_ucredResolve(uint64_t c,` | `static bool dsb_ucredLooksValid(uint64_t u)` |
| 174 | `static int64_t dsb_probeLabelOffset(uint64_t ucred, int64_t preferred)` | (không có) |
| 267 | `- (BOOL)patchProcessPrivileges {` (bắt đầu logic dò 4 slot) | dùng `candP/candA` 2 offset |
| 320 | `uint32_t uidNow = (uint32_t)getuid();` (xác minh rootify LIVE) | (không có — tin mù sau ghi) |
| 347 | `int64_t lblOff = dsb_probeLabelOffset(liveUcred, …)` | `uint64_t label = kread_ptr(ucred + off_ucred_cr_label);` |

Tổng cộng file: **620 dòng**. Nếu file trong repo ngắn hơn (~477 hoặc ~575 dòng)
thì push chưa thay được file mới.

Tổng hợp fix trong file này (run 15→17):
1. Xoá `#import <libproc.h>` — header chỉ có ở macOS SDK (run 15)
2. Xoá `#import <mach/mach_vm.h>` — header `#error` trên iOS SDK → thay bằng
   `extern` prototype `mach_vm_read_overwrite` / `mach_vm_write` (run 16)
3. Thêm `#import "GameOffsets.h"` — thiếu macro `kLegacyGameProcessName`
   gây lỗi `unexpected '@' in program` (run 16)
4. `printf("%@")` → `printf("%s", x.UTF8String)` — macro printf không hỗ trợ `%@` (run 16)

Ngoài `DSProcessBridge.m`, MỌI file khác đã compile OK trên CI (run 16 & 17
xác nhận: ESPDrawingView, ESPManager, FloatingMenuView, GameLogic, ESPPrefs,
MainTabController, StartESPViewController, ConfigViewController, LegacyTweaks,
LogTextView…). XPF/libxpf.dylib build OK. Chỉ cần repo nhận đúng file trên là
run kế tiếp qua hết compile.

## 🔧 Runtime fix — phát hiện "Kernel chưa chạy" dù exploit đã win (2026-09-19)

**Triệu chứng** (log thực tế trên máy): exploit chạy tới `early_kread64(...) ->
0x…feedfacf / win??` (đọc được kernel → exploit THÀNH CÔNG), nhưng app vẫn báo
`✗ Kernel exploit thất bại` → nút START ESP bị chặn "Kernel chưa chạy".

**Nguyên nhân**: `dsb_isValidPtr()` trong `ESP/DSProcessBridge.m` dùng range
USERLAND (`0x10000 … 0x800000000000`) để kiểm tra KERNEL pointer. Kernel pointer
XNU arm64 có dạng `0xffffff…` — LỚN HƠN giới hạn trên → mọi kernel pointer hợp
lệ đều bị coi là "invalid" → kiểm tra proc_self luôn fail.

**Fix**: tách 2 range kiểm tra:
- `dsb_isValidKernelPtr()` — cho proc/ucred/label/walk proc-list. Range lấy từ
  `VM_MIN/MAX_KERNEL_ADDRESS` do `offsets_init()` của exploit set theo từng iOS
  (fallback tĩnh `0xFFFFFFDC00000000 … 0xFFFFFFFBFFFFFFFF`).
- `dsb_isValidUserPtr()` — cho địa chỉ bộ nhớ game (readMemory/writeMemory,
  GameLogic vẫn giữ range userland của nó — đúng cho mục đích đó).

Thêm nữa:
- Fallback xác nhận kernel r/w qua `g_kernel_base` (magic `feedfacf`) nếu
  proc_self hụt, kèm log giá trị proc_self để debug.
- Bỏ 2 lệnh đọc "touch memory" thừa trong walk proc-list (tránh rủi ro panic
  khi gặp entry lạ).

## 🔧 Runtime fix 2 — crash ở bước rootify (ucred ghi nhầm = panic) (2026-09-19)

**Triệu chứng**: exploit win → `✓ Kernel r/w OK! proc_self=… pid=…` → in
`proc=… proc_ro=… ucred=…` → crash ngay sau đó (không in "✓ Rootified").

**Nguyên nhân**: iOS 18.4+ đổi `offsetof(proc_ro, p_ucred)` từ 0x20 → 0x28.
Nếu offsets_init không chọn đúng branch cho thiết bị, "ucred" đọc được thực ra
là kernel object KHÁC (filedesc/pgrp…) — đọc thì không sao, nhưng rootify ghi
32 byte vào object sai → **kernel panic**.

**Fix** (ESP/DSProcessBridge.m — patchProcessPrivileges):
- Probing CẢ HAI offset 0x20/0x28, verify cấu trúc ucred bằng cách CHỈ ĐỌC
  (`dsb_ucredLooksValid`: uid/ruid/svuid/rgid nhỏ, ngroups ≤ 64, cr_label@0x78
  là kernel ptr) — ghi chỉ diễn ra khi ucred ĐÃ verified.
- Offset đúng được tự sửa (`off_proc_ro_p_ucred`) + log rõ.
- Verify fail → hủy rootify, KHÔNG ghi kernel gì cả, log đầy đủ giá trị
  (kèm bảo vệ: không kread vào địa chỉ không phải kernel ptr, vì early_kread
  crash cố ý khi kaddr invalid).
- proc_ro cũng được verify trước khi dùng.

## 🔧 Runtime fix 3 — rootify bị hủy: "Không verify được ucred" → ESP fail (2026-09-19)

**Triệu chứng** (log thật từ thiết bị):
```
[DSB] ✓ Kernel r/w OK! proc_self=0xffffffdd38816db0 pid=526
[DSB] proc_ro=0xffffffdce6e1d030 → ucred@0x28=0xffffffdd339b9db0, ucred@0x20=0x2200230100000001
[DSB] ✗ Không verify được ucred (cả 2 offset đều không giống ucred) — HỦY rootify, không ghi kernel
[DSB]   candP@0x28=0xffffffdd339b9db0: uid=0x1f5 ngroups=0x4 lbl=0x92aaa6dce6d17de0
```
Kernel đã thành công, nhưng rootify bị hủy 5 lần liên tiếp → không có root →
`task_for_pid` không thể thông qua → **ESP fail**.

**Chẩn đoán**: chữ ký ucred cũ yêu cầu `cr_label@0x78` phải là kernel pointer
(offset patchfinder `off_ucred_cr_label=0x78`, ghi cho 17.0–26). Trên máy này
uid@0x18=501 (ĐÚNG uid mobile) và ngroups=4 (hợp lệ) — tức candidate IS ucred —
nhưng `lbl@0x78 = 0x92aaa6dce6d17de0` (rác) → layout ucred của build kernel này
khác giả định → verify fail → rootify bị hủy vĩnh viễn (deterministic).

**Fix** (ESP/DSProcessBridge.m — viết lại `patchProcessPrivileges`):
- **Tự dò layout ucred** (FLAT `uid@0x18` / UNION `uid@0x48`): candidate chỉ được
  chấp nhận khi **uid == ruid == svuid == getuid()** (3 u32 liên tiếp trùng đúng
  uid của mình — không thể trùng ngẫu nhiên → không bao giờ ghi nhầm object khác).
- **Dò p_ucred ở 4 slot** của proc_ro: offset offsets_init + 0x28/0x20/0x18.
- **Rootify thử từng candidate + xác minh SỐNG bằng `getuid()==0`**: nếu ucred
  stale (đã free) thì ghi 0 vô hại, tự động thử slot kế tiếp. Chỉ khi getuid()
  thực sự = 0 mới coi là root thành công (không còn "ghi xong rồi tin").
- **Dò cr_label bằng chữ ký struct label** thay vì tin offset 0x78: slot phải có
  giá trị là kernel ptr ≠ ucred, `l_flags` (u32 đầu) nhỏ, và CẢ `label+0x8`
  (AMFI perpolicy) lẫn `label+0x10` (sandbox perpolicy) đều là kernel pointer —
  chữ ký rất chặt. Offset tìm được tự sửa vào `off_ucred_cr_label`.
- Không tìm được label → KHÔNG blind-write (tránh panic), hexdump ucred 0xC0
  vào log để chẩn đoán, vẫn tiếp tục với root đã ăn.
- Fallback `patch_sandbox_ext()` đã bỏ khỏi path này (nó dùng `off_ucred_cr_label`
  chưa verify → deref địa chỉ rác = nguy cơ panic).

Kết quả mong đợi trên log:
```
[DSB] selfProc=0x… proc_ro=0x… getuid=501
[DSB] probe proc_ro+0x28 → 0x…
[DSB] rootify cand=0x… (layout flat(uid@0x18)) → getuid()=0 ✓ LIVE
[DSB] ✓ Rootified! ucred=0x… , getuid()=0
[DSB]   cr_label probe: ucred+0x78 → label=0x… ✓        ← hoặc slot khác
[DSB] ✓ AMFI label = 0, sandbox label = 0
[DSB] ✓ task_for_pid(…) OK — task port 0x…
[DSB] ✅ CONNECTED: pid=… task=… base=…
```
Nếu vẫn fail: log giờ có hexdump `proc_ro` / `ucred` đầy đủ — gửi lại log là
xác định được layout chính xác ngay.
