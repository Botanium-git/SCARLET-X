#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (PostCounts211)
- (UIView *)sx_211_postViewForPost:(NSDictionary *)post;
@end

@implementation NativeProfileViewController (PostCounts211)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(postViewForPost:));
        Method replacement = class_getInstanceMethod(self, @selector(sx_211_postViewForPost:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (UIView *)sx_211_postViewForPost:(NSDictionary *)post {
    UIView *view = [self sx_211_postViewForPost:post];
    if (![view isKindOfClass:UIStackView.class]) return view;

    UIStackView *stack = (UIStackView *)view;
    NSNumber *reply = [post[@"replyCount"] isKindOfClass:NSNumber.class] ? post[@"replyCount"] : @0;
    NSNumber *retweet = [post[@"retweetCount"] isKindOfClass:NSNumber.class] ? post[@"retweetCount"] : @0;
    NSNumber *favorite = [post[@"favoriteCount"] isKindOfClass:NSNumber.class] ? post[@"favoriteCount"] : @0;

    UILabel *counts = [UILabel new];
    counts.font = [UIFont systemFontOfSize:13];
    counts.textColor = UIColor.secondaryLabelColor;
    counts.numberOfLines = 1;
    counts.text = [NSString stringWithFormat:@"返信 %@    リポスト %@    いいね %@", reply, retweet, favorite];

    NSInteger index = MAX((NSInteger)stack.arrangedSubviews.count - 1, 0);
    [stack insertArrangedSubview:counts atIndex:index];
    return view;
}

@end
