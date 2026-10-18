#import <UIKit/UIKit.h>

static NSString *const SXUpdateSourceURL = @"https://raw.githubusercontent.com/Botanium-git/SCARLET-X/develop/source.json";

@interface SXUpdateViewController : UITableViewController
@property(nonatomic,copy) NSString *latestVersion;
@property(nonatomic,copy) NSString *latestIPAURL;
@property(nonatomic,copy) NSString *status;
@property(nonatomic,assign) BOOL checking;
@end

@implementation SXUpdateViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"アップデート";
    self.status = @"未確認";
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"update"];
    [self checkForUpdates];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"GitHub Releasesで公開されたIPAをLiveContainerへ直接渡します。上書き確認はLiveContainerで行われます。データを保持するには「新規インストール」ではなく既存のcom.scarletx.appを選んでください。更新中はScarlet Xを閉じてください。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"update" forIndexPath:indexPath];
    cell.accessoryType=UITableViewCellAccessoryNone;
    cell.imageView.image=nil;
    cell.textLabel.numberOfLines=0;
    NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"?";
    if(indexPath.row==0) {
        cell.textLabel.text=[NSString stringWithFormat:@"現在: v%@\n配布最新版: %@\n状態: %@",current,self.latestVersion?[@"v" stringByAppendingString:self.latestVersion]:@"未取得",self.status?:@""];
        cell.imageView.image=[UIImage systemImageNamed:@"info.circle"];
    } else if(indexPath.row==1) {
        cell.textLabel.text=@"最新版を再確認";
        cell.imageView.image=[UIImage systemImageNamed:@"arrow.clockwise"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text=@"最新版をLiveContainerでインストール";
        cell.imageView.image=[UIImage systemImageNamed:@"arrow.up.right.square"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.row==1)[self checkForUpdates];
    if(indexPath.row==2)[self openLiveContainer];
}
- (void)checkForUpdates {
    if(self.checking)return;
    self.checking=YES; self.status=@"確認中…";[self.tableView reloadData];
    NSURLComponents *c=[NSURLComponents componentsWithString:SXUpdateSourceURL];
    c.queryItems=@[[NSURLQueryItem queryItemWithName:@"t" value:[NSString stringWithFormat:@"%.0f",NSDate.date.timeIntervalSince1970]]];
    NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:c.URL];
    req.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    req.timeoutInterval=20;
    __weak typeof(self) weakSelf=self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        id payload=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSArray *apps=[payload isKindOfClass:NSDictionary.class] && [payload[@"apps"] isKindOfClass:NSArray.class]?payload[@"apps"]:@[];
        NSString *found=nil;
        NSString *ipaURL=nil;
        for(NSDictionary *app in apps) {
            if(![app isKindOfClass:NSDictionary.class] || ![app[@"bundleIdentifier"] isEqual:@"com.scarletx"])continue;
            found=[app[@"version"] isKindOfClass:NSString.class]?app[@"version"]:nil;
            ipaURL=[app[@"downloadURL"] isKindOfClass:NSString.class]?app[@"downloadURL"]:nil;
            break;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            __strong typeof(weakSelf) self=weakSelf;if(!self)return;
            self.checking=NO;
            if(error || !found.length || !ipaURL.length){self.latestIPAURL=nil;self.status=error.localizedDescription?:@"更新情報を読み取れませんでした";}
            else {
                self.latestVersion=found;
                NSURLComponents *download=[NSURLComponents componentsWithString:ipaURL];
                BOOL valid=[download.scheme isEqualToString:@"https"] && [download.host isEqualToString:@"github.com"] && [download.path hasPrefix:@"/Botanium-git/SCARLET-X/releases/download/"] && [download.path hasSuffix:@".ipa"];
                self.latestIPAURL=valid?ipaURL:nil;
                NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0";
                NSComparisonResult result=[current compare:found options:NSNumericSearch];
                self.status=!valid?@"公開IPAのURLを検証できません":(result==NSOrderedAscending?@"新しいバージョンがあります":(result==NSOrderedSame?@"最新版です":@"このアプリの方が新しいバージョンです"));
            }
            [self.tableView reloadData];
        });
    }] resume];
}
- (void)openLiveContainer {
    NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0";
    if(!self.latestIPAURL.length || !self.latestVersion.length ||
       [current compare:self.latestVersion options:NSNumericSearch]!=NSOrderedAscending) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"更新できません" message:@"新しい公開バージョンが確認できてから実行してください。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSURLComponents *link=[NSURLComponents componentsWithString:@"livecontainer://install"];
    link.queryItems=@[[NSURLQueryItem queryItemWithName:@"url" value:self.latestIPAURL]];
    NSURL *url=link.URL;
    if(!url)return;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        if(!success) {
            UIAlertController *a=[UIAlertController alertControllerWithTitle:@"LiveContainerを開けませんでした" message:@"LiveContainerのSourcesからScarlet Xを選んで更新してください。" preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }];
}

@end
UIViewController *SXCreateUpdateViewController(void) { return [SXUpdateViewController new]; }
