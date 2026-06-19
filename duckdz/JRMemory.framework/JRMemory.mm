#import "JRMemory.framework/JRHelper.h"

@implementation JRHelper

+ (instancetype)shared {
    static JRHelper *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[JRHelper alloc] init];
        shared.cachedAddresses = [NSMutableDictionary dictionary];
    });
    return shared;
}

- (void)fullSearch:(AddrRange)range searchValue:(void*)search size:(size_t)size key:(NSString*)key type:(JRHelperDataType)type {
    JRMemoryEngine engine = JRMemoryEngine(mach_task_self());
    engine.JRScanMemory(range, search, type);
    vector<void*> results = engine.getAllResults();
    
    NSMutableArray *resultArray = [NSMutableArray array];
    for (void* addr : results) {
        [resultArray addObject:@((uint64_t)addr)];
    }
    [self.cachedAddresses setObject:resultArray forKey:key];
}

- (void)refineSearch:(void*)refine size:(size_t)size key:(NSString*)key {
    NSMutableArray *current = [self.cachedAddresses objectForKey:key];
    NSMutableArray *refined = [NSMutableArray array];
    
    for (NSNumber *num in current) {
        uint64_t addr = num.unsignedLongLongValue;
        float value = 0;
        vm_size_t outSize = 0;
        vm_read_overwrite(mach_task_self(), addr, size, (mach_vm_address_t)&value, &outSize);
        
        if (size == sizeof(float)) {
            float target = *(float*)refine;
            if (fabs(value - target) < 0.0001f) {
                [refined addObject:num];
            }
        }
    }
    [self.cachedAddresses setObject:refined forKey:key];
}

- (void)writePatchForKey:(NSString*)key modifyValue:(void*)modify size:(size_t)size type:(JRHelperDataType)type {
    NSMutableArray *current = [self.cachedAddresses objectForKey:key];
    JRMemoryEngine engine = JRMemoryEngine(mach_task_self());
    
    for (NSNumber *num in current) {
        uint64_t addr = num.unsignedLongLongValue;
        engine.JRWriteMemory(addr, modify, type);
    }
}

- (void)restoreOriginalForKey:(NSString*)key originalValue:(void*)original size:(size_t)size type:(JRHelperDataType)type {
    [self writePatchForKey:key modifyValue:original size:size type:type];
}

@end
