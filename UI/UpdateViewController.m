#import <UIKit/UIKit.h>

static NSString *const SXUpdateReleasesAPI = @"https://api.github.com/repos/Botanium-git/SCARLET-X/releases?per_page=30";

@interface SXUpdateViewController : UITableViewController
@property(nonatomic,copy) NSString *latestVersion;
@property(nonatomic,copy) NSString *latestIPAURL;
@property(nonatomic,copy) NSString *status;
@property(nonatomic,assign) BOOL checking;
@property(nonatomic,copy) NSString *lastChecked;
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
        cell.textLabel.text=[NSString stringWithFormat:@"現在: v%@\n配布最新版: %@\n状態: %@\n取得元: GitHub Releases API\n最終確認: %@",current,self.latestVersion?[@"v" stringByAppendingString:self.latestVersion]:@"未取得",self.status?:@"",self.lastChecked?:@"未取得"];
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
    self.checking=YES;
    self.status=@"確認中…";
    [self.tableView reloadData];
    NSURLComponents *components=[NSURLComponents componentsWithString:SXUpdateReleasesAPI];
    NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:components.URL];
    req.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    req.timeoutInterval=20;
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"ScarletX-Updater" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf=self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        NSError *jsonError=nil;
        id parsed=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError]:nil;
        NSArray *releases=[parsed isKindOfClass:NSArray.class]?parsed:nil;
        NSInteger http=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
        NSString *found=nil,*ipaURL=nil;
        for(id item in releases) {
            if(![item isKindOfClass:NSDictionary.class])continue;
            NSDictionary *release=item;
            if([release[@"draft"] boolValue] || [release[@"prerelease"] boolValue])continue;
            NSString *tag=[release[@"tag_name"] isKindOfClass:NSString.class]?release[@"tag_name"]:@"";
            if(![tag hasPrefix:@"v"] || tag.length<2)continue;
            NSString *version=[tag substringFromIndex:1];
            NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
            if([version rangeOfCharacterFromSet:invalid].location!=NSNotFound)continue;
            NSString *expected=[NSString stringWithFormat:@"ScarletX_v%@.ipa",version];
            NSArray *assets=[release[@"assets"] isKindOfClass:NSArray.class]?release[@"assets"]:@[];
            for(id itemAsset in assets) {
                if(![itemAsset isKindOfClass:NSDictionary.class])continue;
                NSDictionary *asset=itemAsset;
                if(![asset[@"name"] isEqual:expected])continue;
                NSString *candidate=[asset[@"browser_download_url"] isKindOfClass:NSString.class]?asset[@"browser_download_url"]:nil;
                NSURLComponents *url=[NSURLComponents componentsWithString:candidate];
                BOOL valid=[url.scheme isEqualToString:@"https"] && [url.host isEqualToString:@"github.com"] &&
                    [url.path isEqualToString:[NSString stringWithFormat:@"/Botanium-git/SCARLET-X/releases/download/%@/%@",tag,expected]];
                if(!valid)continue;
                if(!found || [found compare:version options:NSNumericSearch]==NSOrderedAscending) {
                    found=version;ipaURL=candidate;
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(),^{
            __strong typeof(weakSelf) self=weakSelf;
            if(!self)return;
            self.checking=NO;
            NSDateFormatter *formatter=[NSDateFormatter new];
            formatter.dateFormat=@"yyyy-MM-dd HH:mm:ss";
            self.lastChecked=[formatter stringFromDate:NSDate.date];
            if(error || http!=200 || !found.length || !ipaURL.length) {
                self.latestIPAURL=nil;
                self.latestVersion=nil;
                self.status=error.localizedDescription?:[NSString stringWithFormat:@"取得失敗 (HTTP %ld%@)",(long)http,jsonError?@", JSON不正":@""];
            } else {
                self.latestVersion=found;
                self.latestIPAURL=ipaURL;
                NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0";
                NSComparisonResult order=[current compare:found options:NSNumericSearch];
                self.status=order==NSOrderedAscending?@"新しいバージョンがあります":
                    (order==NSOrderedSame?@"最新版です":@"このアプリの方が新しいバージョンです");
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
