#pragma once

#define kGameFacadeTypeInfo      0xBB46A50
#define kTypeInfoStatics         0xB8
#define kCurrentGame             0x0
#define kCurrentMatchGame        0x8
#define kMatch                   0x90
#define kMatchLocalPlayer        0xD8
#define kCameraControllerManager 0xD8

#define kMainCamera              0x20
#define kCameraInner             0x10

#define kViewMatrixOff          0x80
#define kProjMatrixOff          0xC0
#define kBodyPartTransNode       0x10
#define kHeadNode                0x6A0
#define kHipNode                 0x6A8
#define kLeftAnkleNode           0x6D8
#define kRightAnkleNode          0x6E0
#define kRightToeNode            0x6F0
#define kLeftToeNode             0x6E8
#define kLeftShoulderNode        0x6C0
#define kRightShoulderNode       0x6C8
#define kLeftHandNode            0x720
#define kRightHandNode           0x718
#define kLeftElbowNode           0x730
#define kRightElbowNode          0x728
#define kPlayerIDStruct         0x2D0
#define kPlayerID               0x408
#define kUserID                 0x408
#define kIsClientBot            0x4A0
#define kDataPool               0x70
#define kDataPoolInner          0x10
#define kDataPoolEntriesBase    0x20
#define kDataPoolEntryStride    0x8
#define kDataPoolValue          0x18
#define kAimRotation            0x614
#define kAimRotationAux         0x628
#define kIsFiring               0x0

#define _0x27276BC 0x770  // protected AvatarManager m_AvatarManager; // 0x620 protected AvatarManager FOGJNGDMJKJ; // 0x710

#define _0x28726BD 0x138  // internal IUmaAvatar m_Avatar; // 0x118 internal IUmaAvatar EEAGBKBMBLD; // 0x128

#define _0x2872DCF 0x101  // private bool IsVisible; // 0x101

#define kMainCameraTransform    0x3E8
#define kMyPhysXData            0x1BE8
#define kPhxNpeononogeo         0x20
#define kGhgState               0x10
#define kKnocked                0x1258
#define kMatchPlayerDict        0x148
#define kDictEntries            0x18
#define kDictCount              0x20
#define kIl2CppArrayMaxLength   0x18
#define kIl2CppArrayItems       0x20
#define kDictEntryStrideBytePlayer   24
#define kDictEntryValueOffByte       16
#define kTransformInner         0x10
#define kTransformMatrix        0x38
#define kTransformIndex         0x40
#define kMatrixList             0x18
#define kMatrixIndices          0x20
#define kNickname               0x498
#define kStringFirstChar        0x14

// ─── Weapon ───────────────────────────────────
#define _0x5BC2862 0x6E8
#define _0x2862BCD 0xA0
#define kWeaponCostAmmo         0x7B8
#define kPlayerAttributes       0x700
#define kShootNoReload          0xD9
#define kFastFireOff            0x208
#define kFollowCamera           0x628
#define kFOVOffset              0x70

// ─── Aim / Firing ─────────────────────────────
#define kActiveUISightingWeapon 0x598   // Kiểm tra đang ngắm (ADS)

// ─── Mod engine (CrackTeam parity — FreeFire-DS.ipa phân tích 2026-09) ───
//
// Mọi mod chạy theo pattern "applied-state" như ApplyFlork* của Cofi:
//   bật  → đọc giá trị hiện tại, chỉ GHI khi khác target (không ghi lặp)
//   tắt  → ghi lại giá trị mặc định của game (float scale = 1.0, bool = 0)
//
// ⚠️ PANIC-SAFETY: các ghi này đều là mach_vm_write vào PORT GAME đã
// transplant — KHÔNG BAO GIỜ đụng kernel write. isVaildPtr chặn địa chỉ rác.
// Offset = 0 nghĩa là "chưa có giá trị cho phiên bản game này" → mod TỰ BỊ
// BỎ QUA (không ghi gì), an toàn tuyệt đối; khi có offset mới cho OB mới,
// chỉ cần sửa file này là mod chạy lại.
//
#define kWeaponRecoilContext    0x0     // Weapon* → RecoilContext* (con trỏ)
#define kRecoilContextValue     0x0     // RecoilContext* → float hệ số giật
#define kAttrFastReload         0x0     // PlayerAttributes → float reload scale
#define kAttrRunSpeedScale      0x0     // PlayerAttributes → float tốc độ chạy
#define kAttrFallingSpeedScale  0x0     // PlayerAttributes → float rơi nhanh
#define kAttrWeaponMoveSpeed    0x0     // PlayerAttributes → float di chuyển khi cầm súng
#define kAttrInfiniteHealer     0x0     // PlayerAttributes → bool hồi máu vô hạn
#define kPlayerWaitForForceSync 0x0     // Player* → bool chờ force-sync (no force sync)