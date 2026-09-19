#import "DiagnosticsStore.h"

static NSString * const SXDiagnosticsKey = @"ScarletXDiagnostics";

@implementation DiagnosticsStore
+ (instancetype)shared {
    static DiagnosticsStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [DiagnosticsStore new]; });
    return store;
}
- (void)saveEntry:(NSDictionary *)entry {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *items = [[d arrayForKey:SXDiagnosticsKey] mutableCopy] ?: [NSMutableArray array];
    [items insertObject:entry atIndex:0];
    if (items.count > 200) [items removeObjectsInRange:NSMakeRange(200, items.count - 200)];
    [d setObject:items forKey:SXDiagnosticsKey];
}
- (void)addEvent:(NSString *)title detail:(NSString *)detail url:(NSURL *)url {
    [self saveEntry:@{@"kind":@"event", @"title":title ?: @"Event", @"detail":detail ?: @"", @"url":url.absoluteString ?: @"", @"date":@([[NSDate date] timeIntervalSince1970])}];
}
- (void)addError:(NSString *)title error:(NSError *)error url:(NSURL *)url {
    NSString *detail = [NSString stringWithFormat:@"Domain: %@\nCode: %ld\nDescription: %@",
                        error.domain ?: @"", (long)error.code, error.localizedDescription ?: @""];
    [self saveEntry:@{@"kind":@"error", @"title":title ?: @"Error", @"detail":detail, @"url":url.absoluteString ?: @"", @"date":@([[NSDate date] timeIntervalSince1970])}];
}
- (NSArray<NSDictionary *> *)entries { return [NSUserDefaults.standardUserDefaults arrayForKey:SXDiagnosticsKey] ?: @[]; }
- (void)clear { [NSUserDefaults.standardUserDefaults removeObjectForKey:SXDiagnosticsKey]; }
@end
