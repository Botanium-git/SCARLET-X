#import "SettingsViewController.h"
#import "LogViewController.h"

static NSString * const SXDetailedDiagnosticsKey = @"ScarletXDetailedDiagnostics";
static NSString * const SXDiagResourcesKey = @"ScarletXDiagResources";
static NSString * const SXDiagMenuKey = @"ScarletXDiagMenu";
static NSString * const SXDiagRequestsKey = @"ScarletXDiagRequests";

@interface SXDetailedDiagnosticsViewController : UITableViewController
@end

@implementation SXDetailedDiagnosticsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"詳細診断ログ";
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"必要な計測だけONにできます。変更は次回起動から反映されます。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSArray *titles = @[@"リソース・操作計測", @"メニュー状態・開閉計測", @"メニュー通信計測"];
    NSArray *keys = @[SXDiagResourcesKey, SXDiagMenuKey, SXDiagRequestsKey];
    cell.textLabel.text = titles[indexPath.row];
    cell.imageView.image = [UIImage systemImageNamed:indexPath.row == 0 ? @"speedometer" : (indexPath.row == 1 ? @"rectangle.3.group" : @"network")];
    UISwitch *toggle = [UISwitch new];
    toggle.tag = indexPath.row;
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:keys[indexPath.row]];
    [toggle addTarget:self action:@selector(optionChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)optionChanged:(UISwitch *)sender {
    NSArray *keys = @[SXDiagResourcesKey, SXDiagMenuKey, SXDiagRequestsKey];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:keys[sender.tag]];
}
@end

@implementation SettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 3 : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"ログ" : @"About"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"診断ログ";
            cell.imageView.image = [UIImage systemImageNamed:@"waveform.path.ecg"];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"エラーログ";
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
        } else {
            cell.textLabel.text = @"詳細診断ログ";
            cell.imageView.image = [UIImage systemImageNamed:@"ladybug"];
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
        cell.textLabel.text = [NSString stringWithFormat:@"Scarlet X %@", version];
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0) return;
    if (indexPath.row < 2) {
        SXLogKind kind = indexPath.row == 0 ? SXLogKindDiagnostics : SXLogKindErrors;
        [self.navigationController pushViewController:[[LogViewController alloc] initWithLogKind:kind] animated:YES];
    } else {
        [self.navigationController pushViewController:[SXDetailedDiagnosticsViewController new] animated:YES];
    }
}
@end
