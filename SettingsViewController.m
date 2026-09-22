#import "SettingsViewController.h"
#import "LogViewController.h"

static NSString * const SXDiagResourcesKey = @"ScarletXDiagResources";
static NSString * const SXDiagMenuKey = @"ScarletXDiagMenu";
static NSString * const SXDiagRequestsKey = @"ScarletXDiagRequests";
static NSString * const SXDiagDisplayDOMKey = @"ScarletXDiagDisplayDOM";
static NSString * const SXHideAppDownloadKey = @"ScarletXHideAppDownload";
static NSString * const SXHidePurchaseKey = @"ScarletXHidePurchase";
static NSString * const SXHideUnverifiedCardKey = @"ScarletXHideUnverifiedCard";
static NSString * const SXHideGrokKey = @"ScarletXHideGrok";

@interface SXDetailedDiagnosticsViewController : UITableViewController @end
@interface SXDisplayCustomizationViewController : UITableViewController @end

@implementation SXDetailedDiagnosticsViewController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"詳細診断ログ"; [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 4; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"必要な計測だけONにできます。変更は次回起動から反映されます。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSArray *titles=@[@"リソース・操作計測",@"メニュー状態・開閉計測",@"メニュー通信計測",@"表示要素DOM計測"];
    NSArray *keys=@[SXDiagResourcesKey,SXDiagMenuKey,SXDiagRequestsKey,SXDiagDisplayDOMKey];
    NSArray *icons=@[@"speedometer",@"rectangle.3.group",@"network",@"viewfinder"];
    cell.textLabel.text=titles[indexPath.row]; cell.imageView.image=[UIImage systemImageNamed:icons[indexPath.row]];
    UISwitch *toggle=[UISwitch new]; toggle.tag=indexPath.row; toggle.on=[[NSUserDefaults standardUserDefaults] boolForKey:keys[indexPath.row]];
    [toggle addTarget:self action:@selector(optionChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle; return cell;
}
- (void)optionChanged:(UISwitch *)sender { NSArray *keys=@[SXDiagResourcesKey,SXDiagMenuKey,SXDiagRequestsKey,SXDiagDisplayDOMKey]; [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:keys[sender.tag]]; }
@end

@implementation SXDisplayCustomizationViewController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"表示カスタマイズ"; [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 4; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"X Web上の不要な表示だけを非表示にします。変更は次回起動から反映されます。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSArray *titles=@[@"アプリをダウンロードを非表示",@"購入するを非表示",@"未認証カードを非表示",@"Grokを非表示"];
    NSArray *keys=@[SXHideAppDownloadKey,SXHidePurchaseKey,SXHideUnverifiedCardKey,SXHideGrokKey];
    NSArray *icons=@[@"square.and.arrow.down",@"creditcard",@"checkmark.seal",@"sparkles"];
    cell.textLabel.text=titles[indexPath.row]; cell.imageView.image=[UIImage systemImageNamed:icons[indexPath.row]];
    UISwitch *toggle=[UISwitch new]; toggle.tag=indexPath.row;
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    toggle.on=[d objectForKey:keys[indexPath.row]] ? [d boolForKey:keys[indexPath.row]] : YES;
    [toggle addTarget:self action:@selector(optionChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle; return cell;
}
- (void)optionChanged:(UISwitch *)sender { NSArray *keys=@[SXHideAppDownloadKey,SXHidePurchaseKey,SXHideUnverifiedCardKey,SXHideGrokKey]; [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:keys[sender.tag]]; }
@end

@implementation SettingsViewController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Settings"; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)]; [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"]; }
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section==0?1:(section==1?3:1); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section==0?@"カスタマイズ":(section==1?@"ログ":@"About"); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath]; cell.accessoryType=UITableViewCellAccessoryNone; cell.accessoryView=nil;
    if(indexPath.section==0){ cell.textLabel.text=@"表示カスタマイズ"; cell.imageView.image=[UIImage systemImageNamed:@"eye.slash"]; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    else if(indexPath.section==1){ NSArray *titles=@[@"診断ログ",@"エラーログ",@"詳細診断ログ"]; NSArray *icons=@[@"waveform.path.ecg",@"exclamationmark.triangle",@"ladybug"]; cell.textLabel.text=titles[indexPath.row]; cell.imageView.image=[UIImage systemImageNamed:icons[indexPath.row]]; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    else { NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"?"; cell.textLabel.text=[NSString stringWithFormat:@"Scarlet X %@",version]; cell.imageView.image=[UIImage systemImageNamed:@"info.circle"]; }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.section==0){ [self.navigationController pushViewController:[SXDisplayCustomizationViewController new] animated:YES]; return; }
    if(indexPath.section!=1)return;
    if(indexPath.row<2){ SXLogKind kind=indexPath.row==0?SXLogKindDiagnostics:SXLogKindErrors; [self.navigationController pushViewController:[[LogViewController alloc] initWithLogKind:kind] animated:YES]; }
    else [self.navigationController pushViewController:[SXDetailedDiagnosticsViewController new] animated:YES];
}
@end
