#import <Foundation/Foundation.h>

@interface DiagnosticsStore : NSObject
+ (instancetype)shared;
- (void)addEvent:(NSString *)title detail:(NSString *)detail url:(NSURL *)url;
- (void)addError:(NSString *)title error:(NSError *)error url:(NSURL *)url;
- (NSArray<NSDictionary *> *)entries;
- (void)clear;
@end
