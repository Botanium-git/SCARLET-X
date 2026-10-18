#import <UIKit/UIKit.h>

static NSString *const SXUpdateReleasesAPI = @"https://api.github.com/repos/Botanium-git/SCARLET-X/releases?per_page=30";
static NSString *const SXUpdateSourceURL = @"https://raw.githubusercontent.com/Botanium-git/SCARLET-X/develop/source.json";

@interface SXUpdateViewController : UITableViewController
@property(nonatomic,copy) NSString *latestVersion;
@property(nonatomic,copy) NSString *latestIPAURL;
@property(nonatomic,copy) NSString *status;
@property(nonatomic,assign) BOOL checking;
@property(nonatomic,copy) NSString *lastChecked;
@property(nonatomic,copy) NSString *sourceLabel;
@property(nonatomic,strong) NSDate *lastRequestDate;
@end

@implementation SXUpdateViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"アップデート";
    self.status = @"未確認";
    self.sourceLabel=@"未確認";
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"update"];
    [self checkForUpdates];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"ゲストアプリ実行中の直接インストールはLiveContainerに再起動を要求されるため、更新手順を案内します。Sourcesで既存のcom.scarletx.appを選ぶと上書きできます。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"update" forIndexPath:indexPath];
    cell.accessoryType=UITableViewCellAccessoryNone;
    cell.imageView.image=nil;
    cell.textLabel.numberOfLines=0;
    NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"?";
    if(indexPath.row==0) {
        cell.textLabel.text=[NSString stringWithFormat:@"現在: v%@\n配布最新版: %@\n状態: %@\n取得元: %@\n最終確認: %@",current,self.latestVersion?[@"v" stringByAppendingString:self.latestVersion]:@"未取得",self.status?:@"",self.sourceLabel?:@"未確認",self.lastChecked?:@"未取得"];
        cell.imageView.image=[UIImage systemImageNamed:@"info.circle"];
    } else if(indexPath.row==1) {
        cell.textLabel.text=@"最新版を再確認";
        cell.imageView.image=[UIImage systemImageNamed:@"arrow.clockwise"];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text=@"LiveContainerで更新する手順";
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
    if(self.lastRequestDate && [NSDate.date timeIntervalSinceDate:self.lastRequestDate]<60.0){
        self.status=@"再確認は60秒後にできます（連続アクセス防止）";
        [self.tableView reloadData];return;
    }
    self.lastRequestDate=NSDate.date;
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
                // REST API can return HTTP 403 on shared-IP rate limits; try public source JSON.
                [self checkPublicSourceWithAPIStatus:http error:error];
                return;
            } else {
                self.sourceLabel=@"GitHub Releases API";
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
- (void)checkPublicSourceWithAPIStatus:(NSInteger)apiStatus error:(NSError *)apiError {
    NSURLComponents *components=[NSURLComponents componentsWithString:SXUpdateSourceURL];
    components.queryItems=@[[NSURLQueryItem queryItemWithName:@"check" value:[NSString stringWithFormat:@"%.0f",NSDate.date.timeIntervalSince1970]]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:components.URL];
    request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    request.timeoutInterval=15;
    __weak typeof(self) weakSelf=self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        NSHTTPURLResponse *httpResponse=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)response:nil;
        id payload=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSArray *apps=[payload isKindOfClass:NSDictionary.class] && [payload[@"apps"] isKindOfClass:NSArray.class]?payload[@"apps"]:@[];
        NSString *found=nil,*ipaURL=nil;
        if(httpResponse.statusCode==200 && !error)for(id item in apps) {
            if(![item isKindOfClass:NSDictionary.class])continue;
            NSDictionary *app=item;
            if(![app[@"bundleIdentifier"] isEqual:@"com.scarletx"])continue;
            found=[app[@"version"] isKindOfClass:NSString.class]?app[@"version"]:nil;
            ipaURL=[app[@"downloadURL"] isKindOfClass:NSString.class]?app[@"downloadURL"]:nil;
            break;
        }
        NSURLComponents *url=[NSURLComponents componentsWithString:ipaURL];
        NSString *expected=[NSString stringWithFormat:@"/Botanium-git/SCARLET-X/releases/download/v%@/ScarletX_v%@.ipa",found?:@"",found?:@""];
        BOOL valid=found.length>0 && [url.scheme isEqualToString:@"https"] && [url.host isEqualToString:@"github.com"] && [url.path isEqualToString:expected];
        dispatch_async(dispatch_get_main_queue(),^{
            __strong typeof(weakSelf) self=weakSelf;
            if(!self)return;
            self.checking=NO;
            NSDateFormatter *formatter=[NSDateFormatter new];formatter.dateFormat=@"yyyy-MM-dd HH:mm:ss";
            self.lastChecked=[formatter stringFromDate:NSDate.date];
            self.sourceLabel=@"公開Source（API失敗時の代替）";
            if(valid) {
                self.latestVersion=found;self.latestIPAURL=ipaURL;
                NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0";
                NSComparisonResult order=[current compare:found options:NSNumericSearch];
                self.status=order==NSOrderedAscending?@"新しいバージョンがあります（代替取得）":
                    (order==NSOrderedSame?@"最新版です（代替取得）":@"公開Sourceが現在のアプリより古い可能性があります");
            } else {
                self.latestVersion=nil;self.latestIPAURL=nil;
                self.status=[NSString stringWithFormat:@"取得失敗（API HTTP %ld / Source HTTP %ld）",(long)apiStatus,(long)httpResponse.statusCode];
                if(apiError)self.status=[NSString stringWithFormat:@"通信エラー: %@",apiError.localizedDescription];
            }
            [self.tableView reloadData];
        });
    }] resume];
}
- (void)openLiveContainer {
    NSString *message=@"Scarlet Xの実行中はLiveContainerでインストールできない場合があります。\n\n1. Scarlet Xを終了\n2. LiveContainerを単独で起動\n3. Sources → Scarlet X → インストール\n4. 既存のcom.scarletx.appを選んで上書き\n\n同じバージョンの再インストールにも使えます。";
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"LiveContainerで更新する手順" message:message preferredStyle:UIAlertControllerStyleAlert];
    if(self.latestIPAURL.length) {
        NSString *ipa=self.latestIPAURL;
        [alert addAction:[UIAlertAction actionWithTitle:@"IPAのURLをコピー" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string=ipa;
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"閉じる" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
UIViewController *SXCreateUpdateViewController(void) { return [SXUpdateViewController new]; }
