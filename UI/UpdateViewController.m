#import <UIKit/UIKit.h>

static NSString *const SXUpdateSourceURL = @"https://raw.githubusercontent.com/Botanium-git/SCARLET-X/develop/source.json";

@interface SXUpdateViewController : UITableViewController
@property(nonatomic,copy) NSString *latestVersion;
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
    return @"配布済みの最新版だけを確認します。「LiveContainerを開く」は公式のSources追加リンクを使用します。既にソースを登録している場合は重複と表示されることがあります。そのときはLiveContainerのSourcesでScarlet Xを更新してください。上書き確認では既存のcom.scarletx.appを選んでください。";
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
        cell.textLabel.text=@"LiveContainerを開く（Sources）";
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
        for(NSDictionary *app in apps) {
            if(![app isKindOfClass:NSDictionary.class] || ![app[@"bundleIdentifier"] isEqual:@"com.scarletx"])continue;
            found=[app[@"version"] isKindOfClass:NSString.class]?app[@"version"]:nil;
            break;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            __strong typeof(weakSelf) self=weakSelf;if(!self)return;
            self.checking=NO;
            if(error || !found.length)self.status=error.localizedDescription?:@"更新情報を読み取れませんでした";
            else {
                self.latestVersion=found;
                NSString *current=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"0";
                NSComparisonResult result=[current compare:found options:NSNumericSearch];
                self.status=result==NSOrderedAscending?@"新しいバージョンがあります":(result==NSOrderedSame?@"最新版です":@"このアプリの方が新しいバージョンです");
            }
            [self.tableView reloadData];
        });
    }] resume];
}
- (void)openLiveContainer {
    NSString *encoded=[SXUpdateSourceURL stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *link=[NSString stringWithFormat:@"livecontainer://source?url=%@",encoded];
    NSURL *url=[NSURL URLWithString:link];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        if(!success) {
            UIAlertController *a=[UIAlertController alertControllerWithTitle:@"LiveContainerを開けませんでした" message:@"LiveContainerを手動で開き、SourcesからScarlet Xを選んでください。" preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }];
}
@end
UIViewController *SXCreateUpdateViewController(void) { return [SXUpdateViewController new]; }
