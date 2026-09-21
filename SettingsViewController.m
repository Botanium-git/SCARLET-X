#import "SettingsViewController.h"
#import "LogViewController.h"

@implementation SettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 2 : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"ログ" : @"About"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"診断ログ";
            cell.imageView.image = [UIImage systemImageNamed:@"waveform.path.ecg"];
        } else {
            cell.textLabel.text = @"エラーログ";
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
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
    if (indexPath.section == 0) {
        SXLogKind kind = indexPath.row == 0 ? SXLogKindDiagnostics : SXLogKindErrors;
        [self.navigationController pushViewController:[[LogViewController alloc] initWithLogKind:kind] animated:YES];
    }
}
@end
