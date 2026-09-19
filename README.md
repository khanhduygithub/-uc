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
darksword-kexploit-fun/ESP/DSProcessBridge.m   ← 477 dòng (bản cũ ngắn hơn ~13 dòng)
```

**Kiểm tra nhanh trên github.com** — mở `darksword-kexploit-fun/ESP/DSProcessBridge.m`:

| Dòng | Bản ĐÚNG (zip này) | Bản CŨ (build fail) |
|---|---|---|
| 29 | `#import "GameOffsets.h"` | `#import "../kexploit/kexploit_opa334.h"` |
| ~43–53 | `extern kern_return_t mach_vm_read_overwrite(...)` | `#import <mach/mach_vm.h>` |
| 413 | `pid = [self findGamePID:@kLegacyGameProcessName];` (có macro → OK) | cùng dòng nhưng thiếu macro → `unexpected '@'` |

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
