#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <math.h>

@implementation NativeProfileViewController (NativeCountFormat238)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(sx_215_actionItemWithSymbol:count:));
        Method replacement=class_getInstanceMethod(self,@selector(sx238_actionItemWithSymbol:count:));
        if(target&&replacement){
            class_replaceMethod(self,@selector(sx_215_actionItemWithSymbol:count:),method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (NSString *)sx238_compactCount:(NSInteger)value {
    if(value<10000)return [NSString stringWithFormat:@"%ld",(long)value];
    double unit=10000.0;
    NSString *suffix=@"万";
    if(value>=100000000){ unit=100000000.0; suffix=@"億"; }
    double scaled=(double)value/unit;
    double rounded=round(scaled*10.0)/10.0;
    if(fabs(rounded-round(rounded))<0.0001){
        return [NSString stringWithFormat:@"%.0f%@",rounded,suffix];
    }
    return [NSString stringWithFormat:@"%.1f%@",rounded,suffix];
}

- (UIView *)sx238_actionItemWithSymbol:(NSString *)symbol count:(NSNumber *)count {
    UIStackView *item=[UIStackView new];
    item.axis=UILayoutConstraintAxisHorizontal;
    item.alignment=UIStackViewAlignmentCenter;
    item.spacing=5;

    UIImageView *icon=[UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints=NO;
    icon.image=[UIImage systemImageNamed:symbol];
    icon.tintColor=UIColor.secondaryLabelColor;
    icon.contentMode=UIViewContentModeScaleAspectFit;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:17],
        [icon.heightAnchor constraintEqualToConstant:17]
    ]];
    [item addArrangedSubview:icon];

    NSInteger value=[count respondsToSelector:@selector(integerValue)]?[count integerValue]:0;
    if(value>0){
        UILabel *label=[UILabel new];
        label.font=[UIFont systemFontOfSize:12];
        label.textColor=UIColor.secondaryLabelColor;
        label.text=[self sx238_compactCount:value];
        [item addArrangedSubview:label];
    }
    return item;
}

@end
