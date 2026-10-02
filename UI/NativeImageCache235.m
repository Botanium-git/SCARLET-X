#import "NativeProfileViewController.h"
#import <objc/runtime.h>

static char SX235ImageURLKey;

static NSCache<NSString *, UIImage *> *SX235ImageCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache=[NSCache new];
        cache.countLimit=256;
        cache.totalCostLimit=64*1024*1024;
    });
    return cache;
}

static NSMutableDictionary<NSString *, NSHashTable<UIImageView *> *> *SX235InflightViews(void) {
    static NSMutableDictionary<NSString *, NSHashTable<UIImageView *> *> *inflight;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ inflight=[NSMutableDictionary dictionary]; });
    return inflight;
}

@interface NativeProfileViewController (NativeImageCache235Private)
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
@end

@implementation NativeProfileViewController (NativeImageCache235)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(loadImageURLString:into:));
        Method replacement=class_getInstanceMethod(self,@selector(sx235_loadImageURLString:into:));
        if(target&&replacement){
            class_replaceMethod(self,@selector(loadImageURLString:into:),method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (void)sx235_loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView {
    if(![urlString isKindOfClass:NSString.class]||urlString.length==0||![imageView isKindOfClass:UIImageView.class])return;
    NSURL *url=[NSURL URLWithString:urlString];
    if(!url)return;

    objc_setAssociatedObject(imageView,&SX235ImageURLKey,urlString,OBJC_ASSOCIATION_COPY_NONATOMIC);

    UIImage *cached=[SX235ImageCache() objectForKey:urlString];
    if(cached){
        void (^applyCached)(void)=^{
            NSString *current=objc_getAssociatedObject(imageView,&SX235ImageURLKey);
            if([current isEqualToString:urlString])imageView.image=cached;
        };
        if(NSThread.isMainThread)applyCached();
        else dispatch_async(dispatch_get_main_queue(),applyCached);
        return;
    }

    NSMutableDictionary *inflight=SX235InflightViews();
    __block BOOL shouldStart=NO;
    @synchronized(inflight){
        NSHashTable<UIImageView *> *views=inflight[urlString];
        if(!views){
            views=[NSHashTable weakObjectsHashTable];
            inflight[urlString]=views;
            shouldStart=YES;
        }
        [views addObject:imageView];
    }
    if(!shouldStart)return;

    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.cachePolicy=NSURLRequestUseProtocolCachePolicy;
    request.timeoutInterval=15.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        UIImage *image=(data.length>0)?[UIImage imageWithData:data]:nil;
        if(image){
            NSUInteger cost=data.length;
            CGImageRef cg=image.CGImage;
            if(cg){
                size_t row=CGImageGetBytesPerRow(cg);
                size_t height=CGImageGetHeight(cg);
                if(row>0&&height>0&&row<=NSUIntegerMax/height)cost=(NSUInteger)(row*height);
            }
            [SX235ImageCache() setObject:image forKey:urlString cost:cost];
        }

        __block NSArray<UIImageView *> *targets=@[];
        @synchronized(inflight){
            NSHashTable<UIImageView *> *views=inflight[urlString];
            targets=views.allObjects?:@[];
            [inflight removeObjectForKey:urlString];
        }
        if(!image)return;

        dispatch_async(dispatch_get_main_queue(),^{
            for(UIImageView *target in targets){
                NSString *current=objc_getAssociatedObject(target,&SX235ImageURLKey);
                if([current isEqualToString:urlString])target.image=image;
            }
        });
    }] resume];
}

@end
