# PHÂN TÍCH: CrackTeam dùng TrollStore — chuyển sang DarkSword có dùng như nhau được không?

> Trạng thái: **ĐÃ PHÂN TÍCH + ĐÃ REMAKE** (chuẩn hóa 2026-09-11)
> Repo: `-uc` / `darksword/` — build trực tiếp bằng Xcode, **không TrollStore, không jailbreak**.

---

## 1. CrackTeam hoạt động nhờ TrollStore ở đâu?

CrackTeam (FFExternal, bundle `vn.CrackIOSVN.freefireth`) là một app Theos build ra `.tipa`
cài qua TrollStore. Toàn bộ "phép màu" của nó nằm ở **tệp entitlements được TrollStore ký
không giới hạn** (`layout/entitlements.plist`):

| Nhóm quyền trong entitlements của CrackTeam | Vai trò thực tế |
|---|---|
| `platform-application`, `run-unsigned-code`, `get-task-allow` | App được coi như app hệ thống, ký tự do, không bị AMFI chặn |
| `task_for_pid-allow`, `com.apple.system-task-ports` | **Attach chuẩn**: `task_for_pid()` trả về task port của Free Fire |
| `proc_info-allow` | `sysctl(KERN_PROC_ALL)` + `proc_listallpids` thấy toàn bộ process |
| `com.apple.private.security.no-sandbox`, `container-manager`, `disk-device-access` | Đọc/ghi ngoài sandbox, đọc PID_PATH ở `/var/mobile/Library/Caches` |
| `com.apple.springboard.accessibility-window-hosting`, `com.apple.springboard-ui.client` | **Đăng ký window đè lên game**: `SBSAccessibilityWindowHostingController registerWindowWithContextID:atLevel:` gọi TRỰC TIẾP từ process của app |
| `com.apple.springboard.launchapplications`, `com.apple.frontboard.debugapplications` | Tự mở game bằng `SBSLaunchApplicationWithIdentifier` |
| `com.apple.backboard.client`, `com.apple.private.hid.*` | Sự kiện HID/touch cho HUD |
| `com.apple.private.kernel.jetsam` | Không bị jetsam giết khi nằm nền |

Ngoài ra TrollStore còn cho phép:
- Cài app ra vùng hệ thống **không cần ký developer**, không bị hết hạn 7 ngày;
- App HUD (`HUDApp.mm` + `HUDHelper.mm`) được **spawn như tiến trình con root**
  (persona uid=0 qua `posix_spawnattr_set_persona_np`) — thứ app thường không thể.

### Cơ chế process "chuẩn" của CrackTeam (giữ nguyên làm gốc cho DarkSword)

```
GetGameProcesspid("FreeFire")                 // sysctl KERN_PROC_ALL + p_comm strstr
GetGameModule_Base("FreeFire")                // task_for_PID(pid) -> get_task_for_PID
  └─ task_info(TASK_DYLD_INFO)                // đọc dyld_all_image_infos của game
  └─ vm_read(image array + paths)             // tìm base của UnityFramework
_read/_write(addr, buf, len)                  // mach_vm_read_overwrite / mach_vm_write
```
→ Toàn bộ R/W bộ nhớ game là **API Mach chuẩn** trên task port của game. Nhanh, ổn,
không đụng kernel. Đây chính là thứ "chuẩn" mà DarkSword phải có lại.

### Cơ chế SpringBoard "chuẩn" của CrackTeam

```
HUDMainWindow: _isSystemWindow=YES, _isWindowServerHostingManaged=NO,
               _isSecure=YES, _shouldCreateContextAsSecure=YES
window:        setFrame(landscape) -> center -> _setInterfaceOrientation:
               -> CGAffineTransform ±90° -> bounds -> windowLevel 10000010
đăng ký:       [[SBSAccessibilityWindowHostingController alloc] init]
               [invocation setSelector: registerWindowWithContextID:atLevel:]
               [invocation invoke]          // TRONG process của app
touch:         TSEventFetcher + KIF (UITouch/IOHIDEvent additions)
sống nền:      process spawn detached — không bị suspend
```

---

## 2. Chuyển sang DarkSword — có dùng NGUYÊN bản như nhau được không?

### Trả lời ngắn: **KHÔNG dùng trực tiếp được — nhưng được remake 100% chức năng.**

Ba lý do cản trở, theo thứ tự nghiêm trọng:

1. **Entitlements không thể có.** DarkSword được build bằng Xcode + ký developer thường
   (CODE_SIGN_ENTITLEMENTS = ""). `task_for_pid-allow`, `platform-application`,
   `no-sandbox`… là entitlement platform chỉ AMFI cấp cho Apple/TrollStore — **không có
   cách nào hợp lệ để nhúng vào bản sideload**. Nghĩa là mọi đường dựa trên entitlement
   của CrackTeam đều chết ngay từ câu lệnh đầu tiên.
2. **Không spawn được tiến trình HUD root.** CrackTeam tách HUD ra tiến trình con
   (persona uid=0). App thường không có `posix_spawnattr_set_persona_np` hiệu lực.
3. **Gọi SBS trực tiếp từ process bị từ chối.** `registerWindowWithContextID:atLevel:`
   kiểm tra entitlement caller phía SpringBoard khi gọi qua Mach từ app thường.

### Nhưng — flow API thì GIỮ NGUYÊN, chỉ thay "nguồn quyền"

DarkSword đã có **kernel R/W** (kexploit_opa334: race zone TCP socket + icmp6filter trên
iOS 18.5 iPhone11,6). Kernel R/W cho phép tự cấp lại chính mình từng quyền mà không cần
TrollStore. Bảng đối chiếu đầy đủ:

| Cơ chế CrackTeam (TrollStore) | Bản remake DarkSword (kernel) | Trạng thái |
|---|---|---|
| `task_for_pid()` nhờ `task_for_pid-allow` | **Port transplant** (`esp/espkrw.m`): cấp mach port trong chính mình → tìm `ipc_entry` qua `task_get_ipc_port_table_entry` → ghi `io_bits = IKOT_TASK`, `ip_kobject = game task` → port đó CHÍNH LÀ task port của game. Sau bước này `mach_vm_read_overwrite/mach_vm_write/task_info` chạy như bản TrollStore **byte-for-byte** | ✅ Đã có, verify read-back |
| `sysctl KERN_PROC_ALL` nhờ `proc_info-allow` | Trên iOS 18 sandbox sysctl bị EPERM → hybrid: sysctl trước (rẻ), fallback `proc_find_by_name` qua kernel R/W (`espkrw.m`, throttle 1Hz ở `pid.mm` để không bão kernel mỗi frame) | ✅ Đã có (Task 18) |
| Đăng ký window với SpringBoard nhờ `accessibility-window-hosting` | **RemoteCall trong SpringBoard** (`esp/esphost.mm`): mở phiên kernel → nhúng thread trojan vào SpringBoard → dựng chuỗi `NSInvocation` **bên trong SpringBoard** (`signatureWithObjCTypes:"v@:Id"` → `setTarget: [SBSAccessibilityWindowHostingController new]` → `setSelector: registerWindowWithContextID:atLevel:` → `invoke` trên main thread SB). Chạy TRONG SpringBoard thì KHÔNG còn là caller ngoài → không có bước kiểm entitlement | ✅ Đã có |
| `SBSLaunchApplicationWithIdentifier` mở game | Cùng call nhưng thực hiện **trong SpringBoard** qua `r_dlsym_call(5, "SBSLaunchApplicationWithIdentifier", …)` + fallback `SBApplicationController launchApplicationWithBundleID:` | ✅ Đã có |
| Process HUD spawn root, không suspend | App chủ tự giữ sống bằng **audio keep-alive** (`UIBackgroundModes=audio` + silent loop) — mọi app đều khai báo được trong Info.plist | ✅ Đã có |
| Tìm pid mỗi 2.5s/8s, game thoát thì `exit(0)` | Không `exit(0)` (đây là app chính, không phải HUD con) → `esp_krw_game_alive()` kiểm proc theo pid-reuse-safe + auto-heal tự dựng lại bridge khi game mở lại | ✅ Đã có |
| `HUDMainWindow` system-window flags | **Bổ sung lần này**: `ESPHostWindow` override `_isSystemWindow=YES`, `_isWindowServerHostingManaged=NO`, `_isSecure=YES`, `_shouldCreateContextAsSecure=YES` — điều kiện để CAContext được window server coi là system window khi host | 🆕 Chuẩn hóa 2026-09-11 |
| Xoay window: `setFrame landscape → center → _setInterfaceOrientation: → transform ±90° → bounds`, level 10000010 | **Bổ sung lần này**: `esphost_apply_window_geometry()` port nguyên chuỗi trên; thêm observer `UIDeviceOrientationDidChange` vì game đổi hướng lobby portrait ↔ trận landscape (HUD cũ set 1 lần lúc spawn) | 🆕 Chuẩn hóa 2026-09-11 |
| `TSEventFetcher` + KIF (`UITouch-KIFAdditions`, `IOHIDEvent+KIF`) tổng hợp touch cho HUD | **Bổ sung lần này**: port nguyên bộ vào `esp/sources/` (+headers private vào `esp/headers/`, link `-framework IOKit`). ESP window mặc định vẫn display-only (`hitTest` nil) đúng như ESP view CrackTeam (`userInteractionEnabled=NO`); hạ tầng sẵn sàng cho menu tương tác sau này | 🆕 Chuẩn hóa 2026-09-11 |
| Headers private (SBS/BackBoard/UI*+Private/IOKit+SPI) | Port 7 headers đang dùng thật vào `esp/headers/` | 🆕 |

---

## 3. Vì sao cách này "chuẩn attach" như CrackTeam

- **Sau transplant, mọi thao tác bộ nhớ là API Mach chuẩn** (`mach_vm_read_overwrite`,
  `mach_vm_write`, `task_info(TASK_DYLD_INFO)`) trên task port thật của game — cùng bản
  chất với `task_for_pid` của CrackTeam, không phải đọc-ghi từng byte qua kernel primitive
  (chậm, rủi ro). `pid.mm` giữ nguyên 100% logic CrackTeam: cache module base, dò
  UnityFramework qua dyld image list.
- **Window là window thật, đăng ký với render server** bằng đúng API SpringBoard dùng cho
  AssistiveTouch/SwitchControl (`registerWindowWithContextID:atLevel:` level 10000010) —
  đè lên game kể cả khi game fullscreen, không cần chèn dylib vào Free Fire.
- **Touch synthesis là hạ tầng chuẩn KIF** (dùng trong test automation của chính Apple
  ecosystem) — không phụ thuộc TrollStore.

## 4. Rủi ro / khác biệt còn lại so với CrackTeam

| Hạn chế | Chi tiết | Đánh giá |
|---|---|---|
| Cần chạy exploit trước | ESP chỉ sống sau khi "Start Darksword" thành công (kernel R/W sẵn sàng). CrackTeam không cần bước này | Chấp nhận — đây là bản chất của hướng kernel |
| Session SpringBoard | Đăng ký window cần phiên RemoteCall mở (kernel). Respring làm mất đăng ký → pipeline tự thử đăng ký lại khi có phiên | Đã có auto-retry |
| Kernel panic risk | Thao tác kernel sai có panic (đã vá 2 lớp trong kexploit_opa334: leak pe_v1 + "immortal from birth") | Rủi ro thấp nhất có thể, không tồn tại ở bản TrollStore |
| Nhận diện | App thường + audio background: Apple không ký đặc biệt gì; khác biệt duy nhất là hành vi runtime | Tương đương CrackTeam |
| `proc_listallpids` (`get_pid_by_name`) | Cần `proc_info-allow` — trên bản DarkSword hàm này không dùng được; mọi caller đã chuyển qua `GetGameProcesspid` (sysctl/kernel hybrid) | Đã loại khỏi đường nóng |

## 5. Kết luận

- CrackTeam **không thể dùng lại nguyên bản** trên DarkSword vì toàn bộ quyền lực của nó
  đến từ entitlements mà chỉ TrollStore cấp được.
- **Mỗi entitlement đều có bản thay thế bằng kernel R/W** và DarkSword đã có đủ: port
  transplant thay `task_for_pid`, RemoteCall-trong-SpringBoard thay
  `accessibility-window-hosting`/`launchapplications`, audio keep-alive thay HUD process
  detached.
- Chuẩn hóa 2026-09-11 lần cuối: system-window flags, chuỗi geometry/xoay chuẩn
  CrackTeam, TSEventFetcher + KIF + headers private — hoàn tất bộ "process chuẩn +
  SpringBoard chuẩn", build trực tiếp bằng Xcode.
