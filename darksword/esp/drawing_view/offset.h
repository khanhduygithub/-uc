#pragma once

#define kGameFacadeTypeInfo      0xC012848
#define kTypeInfoStatics         0xB8
#define kCurrentGame             0x0
#define kCurrentMatchGame        0x8
#define kMatch                   0x90
#define kMatchLocalPlayer        0xD8
#define kCameraControllerManager 0xD8

#define kMainCamera              0x20
#define kCameraInner            0x10

#define kViewMatrixOff          0x80
#define kProjMatrixOff          0xC0
#define kBodyPartTransNode       0x10
#define kHeadNode               0x638
#define kHipNode                0x640
#define kLeftAnkleNode           0x670
#define kRightAnkleNode          0x678
#define kRightToeNode            0x688
#define kLeftToeNode             0x680
#define kLeftShoulderNode        0x658
#define kRightShoulderNode       0x660
#define kLeftHandNode            0x6B8
#define kRightHandNode           0x6B0
#define kLeftElbowNode           0x6C8
#define kRightElbowNode          0x6C0
#define kPlayerIDStruct         0x2D0
#define kPlayerID               0x3A0
#define kUserID                 0x3A0
#define kIsClientBot            0x448
#define kDataPool               0x70
#define kDataPoolInner          0x10
#define kDataPoolEntriesBase    0x20
#define kDataPoolEntryStride    0x8
#define kDataPoolValue          0x18
#define kAimRotation            0x5AC
#define kAimRotationAux         0x5BC
#define kIsFiring               0x770

#define _0x27276BC 0x708
#define _0x28726BD 0x138
#define _0x2872DCF 0x101

#define kMainCameraTransform    0x380
#define kMyPhysXData            0x1B80
#define kPhxNpeononogeo         0x20
#define kGhgState               0x10
#define kKnocked                0x1150
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
#define kNickname               0x430
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