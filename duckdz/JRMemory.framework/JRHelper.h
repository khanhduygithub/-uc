#import <Foundation/Foundation.h>
#import "JRMemory.framework/Headers/MemScan.h"
#import <mach/mach.h>

// Patch: manually define search types
#define JR_Search_Type_I32 0
#define JR_Search_Type_I64 1
#define JR_Search_Type_Float 4

typedef enum : int {
    JRHelper_Type_I32 = JR_Search_Type_I32,
    JRHelper_Type_I64 = JR_Search_Type_I64,
    JRHelper_Type_Float = JR_Search_Type_Float
} JRHelperDataType;

@interface JRHelper : NSObject

@property (nonatomic, strong) NSMutableDictionary *cachedAddresses;

+ (instancetype)shared;

- (void)fullSearch:(AddrRange)range searchValue:(void*)search size:(size_t)size key:(NSString*)key type:(JRHelperDataType)type;

- (void)refineSearch:(void*)refine size:(size_t)size key:(NSString*)key;

- (void)writePatchForKey:(NSString*)key modifyValue:(void*)modify size:(size_t)size type:(JRHelperDataType)type;

- (void)restoreOriginalForKey:(NSString*)key originalValue:(void*)original size:(size_t)size type:(JRHelperDataType)type;

@end
