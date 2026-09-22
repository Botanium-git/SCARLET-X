#import "DiagnosticsStore.h"

static NSString * const SXDiagnosticEventsKey = @"ScarletXDiagnosticEvents";
static NSString * const SXErrorLogKey = @"ScarletXErrorLog";

@implementation DiagnosticsStore
+ (instancetype)shared {
    static DiagnosticsStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [DiagnosticsStore new]; });
    return store;
}
- (void)saveEntry:(NSDictionary *)entry key:(NSString *)key {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *items = [[d arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    [items insertObject:entry atIndex:0];
    if (items.count > 200) [items removeObjectsInRange:NSMakeRange(200, items.count - 200)];
    [d setObject:items forKey:key];
}
- (void)addEvent:(NSString *)title detail:(NSString *)detail url:(NSURL *)url {
    [self saveEntry:@{@"kind":@"event", @"title":title ?: @"Event", @"detail":detail ?: @"", @"url":url.absoluteString ?: @"", @"date":@([[NSDate date] timeIntervalSince1970])} key:SXDiagnosticEventsKey];
}
- (void)addError:(NSString *)title error:(NSError *)error url:(NSURL *)url {
    NSString *detail = [NSString stringWithFormat:@"Domain: %@\nCode: %ld\nDescription: %@",
                        error.domain ?: @"", (long)error.code, error.localizedDescription ?: @""];
    [self saveEntry:@{@"kind":@"error", @"title":title ?: @"Error", @"detail":detail, @"url":url.absoluteString ?: @"", @"date":@([[NSDate date] timeIntervalSince1970])} key:SXErrorLogKey];
}
- (NSArray<NSDictionary *> *)diagnosticEntries { return [NSUserDefaults.standardUserDefaults arrayForKey:SXDiagnosticEventsKey] ?: @[]; }
- (NSArray<NSDictionary *> *)errorEntries { return [NSUserDefaults.standardUserDefaults arrayForKey:SXErrorLogKey] ?: @[]; }
- (void)clearDiagnostics { [NSUserDefaults.standardUserDefaults removeObjectForKey:SXDiagnosticEventsKey]; }
- (void)clearErrors { [NSUserDefaults.standardUserDefaults removeObjectForKey:SXErrorLogKey]; }
@end
