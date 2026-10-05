#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (NativeProfileQuotes256Private)
- (UIView *)postViewForPost:(NSDictionary *)post;
- (NSString *)stringValue:(id)value;
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
- (UIView *)sx_212_mediaGridForMedia:(NSArray *)mediaItems;
@end

static UIView *SX256QuoteCard(NativeProfileViewController *profile, NSDictionary *quote) {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = 12.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = UIColor.separatorColor.CGColor;
    card.clipsToBounds = YES;

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 7.0;
    stack.layoutMargins = UIEdgeInsetsMake(10, 11, 10, 11);
    stack.layoutMarginsRelativeArrangement = YES;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];

    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 6.0;
    [stack addArrangedSubview:header];

    UIImageView *avatar = [UIImageView new];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.backgroundColor = UIColor.secondarySystemBackgroundColor;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 10.0;
    avatar.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:20.0],
        [avatar.heightAnchor constraintEqualToConstant:20.0]
    ]];
    [header addArrangedSubview:avatar];
    NSString *avatarURL = [profile stringValue:quote[@"authorAvatarURL"]];
    if (avatarURL.length) [profile loadImageURLString:avatarURL into:avatar];

    UILabel *name = [UILabel new];
    name.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    name.text = [profile stringValue:quote[@"authorName"]];
    [name setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:name];

    NSString *handleText = [profile stringValue:quote[@"authorHandle"]];
    if (handleText.length && ![handleText hasPrefix:@"@"]) handleText = [@"@" stringByAppendingString:handleText];
    UILabel *handle = [UILabel new];
    handle.font = [UIFont systemFontOfSize:14];
    handle.textColor = UIColor.secondaryLabelColor;
    handle.lineBreakMode = NSLineBreakByTruncatingTail;
    handle.text = handleText;
    [handle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:handle];

    UIView *spacer = [UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:spacer];

    NSString *text = [profile stringValue:quote[@"text"]];
    if (text.length) {
        UILabel *body = [UILabel new];
        body.font = [UIFont systemFontOfSize:14];
        body.numberOfLines = 0;
        body.text = text;
        [stack addArrangedSubview:body];
    }

    NSArray *media = [quote[@"media"] isKindOfClass:NSArray.class] ? quote[@"media"] : @[];
    if (media.count == 0) {
        NSString *legacyURL = [profile stringValue:quote[@"mediaURL"]];
        if (legacyURL.length) media = @[@{ @"type": @"photo", @"previewURL": legacyURL }];
    }
    if (media.count && [profile respondsToSelector:@selector(sx_212_mediaGridForMedia:)]) {
        UIView *grid = [profile sx_212_mediaGridForMedia:media];
        if (grid) [stack addArrangedSubview:grid];
    }

    return card;
}

static UIStackView *SX256ContentStackFromPostView(UIView *view) {
    if (![view isKindOfClass:UIStackView.class]) return nil;
    UIStackView *root = (UIStackView *)view;
    for (UIView *candidate in root.arrangedSubviews) {
        if (![candidate isKindOfClass:UIStackView.class]) continue;
        UIStackView *row = (UIStackView *)candidate;
        if (row.axis != UILayoutConstraintAxisHorizontal || row.arrangedSubviews.count < 2) continue;
        UIView *content = row.arrangedSubviews[1];
        if ([content isKindOfClass:UIStackView.class] && ((UIStackView *)content).axis == UILayoutConstraintAxisVertical) {
            return (UIStackView *)content;
        }
    }
    return nil;
}

static UIView *(*SX256PreviousPostViewIMP)(id, SEL, NSDictionary *) = NULL;

static UIView *SX256PostView(id selfObject, SEL _cmd, NSDictionary *post) {
    UIView *view = SX256PreviousPostViewIMP ? SX256PreviousPostViewIMP(selfObject, _cmd, post) : nil;
    NSDictionary *quote = [post[@"quoted"] isKindOfClass:NSDictionary.class] ? post[@"quoted"] : nil;
    if (!quote) return view;

    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    UIStackView *content = SX256ContentStackFromPostView(view);
    if (!content) return view;

    UIView *card = SX256QuoteCard(profile, quote);
    NSUInteger count = content.arrangedSubviews.count;
    NSUInteger index = count > 0 ? count - 1 : 0;
    [content insertArrangedSubview:card atIndex:index];
    if (index > 0) [content setCustomSpacing:9.0 afterView:content.arrangedSubviews[index - 1]];
    [content setCustomSpacing:6.0 afterView:card];
    return view;
}

@interface NativeProfileViewController (NativeProfileQuotes256)
@end

@implementation NativeProfileViewController (NativeProfileQuotes256)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;
        SEL selector = @selector(postViewForPost:);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) return;
        IMP current = method_getImplementation(method);
        if (current == (IMP)SX256PostView) return;
        SX256PreviousPostViewIMP = (UIView *(*)(id, SEL, NSDictionary *))current;
        class_replaceMethod(cls, selector, (IMP)SX256PostView, method_getTypeEncoding(method));
    });
}

@end
