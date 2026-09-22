#import "SettingsViewController.h"
#import "LogViewController.h"

static NSString * const SXDetailedDiagnosticsKey = @"ScarletXDetailedDiagnostics";

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
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"詳細診断ログの切り替えは次回起動から反映されます。" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"診断ログ";
            cell.imageView.image = [UIImage systemImageNamed:@"waveform.path.ecg"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"エラーログ";
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"詳細診断ログ";
            cell.imageView.image = [UIImage systemImageNamed:@"ladybug"];
            UISwitch *toggle = [UISwitch new];
            toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:SXDetailedDiagnosticsKey];
            [toggle addTarget:self action:@selector(detailedDiagnosticsChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
    } else {
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
        cell.textLabel.text = [NSString stringWithFormat:@"Scarlet X %@", version];
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
    }
    return cell;
}
- (void)detailedDiagnosticsChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:SXDetailedDiagnosticsKey];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row < 2) {
        SXLogKind kind = indexPath.row == 0 ? SXLogKindDiagnostics : SXLogKindErrors;
        [self.navigationController pushViewController:[[LogViewController alloc] initWithLogKind:kind] animated:YES];
    }
}
@end
