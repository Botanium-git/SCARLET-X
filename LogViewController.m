#import "LogViewController.h"
#import "DiagnosticsStore.h"

@interface LogViewController ()
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,strong) NSDateFormatter *formatter;
@end

@implementation LogViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Error Log";
    self.formatter = [NSDateFormatter new];
    self.formatter.dateFormat = @"MM/dd HH:mm:ss";
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearLog)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(exportJSON)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"] style:UIBarButtonItemStylePlain target:self action:@selector(copyAll)]
    ];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"log"];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; self.items = DiagnosticsStore.shared.entries; [self.tableView reloadData]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *e = self.items[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"log" forIndexPath:indexPath];
    cell.textLabel.numberOfLines = 0;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[e[@"date"] doubleValue]];
    NSString *mark = [e[@"kind"] isEqual:@"error"] ? @"❌" : @"•";
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@  %@\n%@\n%@", mark, e[@"title"], [self.formatter stringFromDate:date], e[@"detail"], e[@"url"]];
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    return cell;
}
- (NSString *)allText {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *e in self.items) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[e[@"date"] doubleValue]];
        [rows addObject:[NSString stringWithFormat:@"[%@] %@\n%@\nURL: %@", [self.formatter stringFromDate:date], e[@"title"], e[@"detail"], e[@"url"]]];
    }
    return [rows componentsJoinedByString:@"\n\n"];
}
- (void)copyAll { UIPasteboard.generalPasteboard.string = [self allText]; }
- (void)exportJSON {
    NSArray *entries = DiagnosticsStore.shared.entries;
    NSDictionary *export = @{
        @"format": @"ScarletXDiagnostics",
        @"version": @1,
        @"exportedAt": @([[NSDate date] timeIntervalSince1970]),
        @"appVersion": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        @"build": NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"",
        @"entries": entries ?: @[]
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:export options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Failed" message:error.localizedDescription ?: @"Could not create diagnostic JSON." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSDateFormatter *nameFormatter = [NSDateFormatter new];
    nameFormatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *name = [NSString stringWithFormat:@"ScarletX_Log_%@.json", [nameFormatter stringFromDate:[NSDate date]]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    if (![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Failed" message:error.localizedDescription ?: @"Could not write diagnostic JSON." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.count > 1 ? self.navigationItem.rightBarButtonItems[1] : nil;
    [self presentViewController:share animated:YES completion:nil];
}
- (void)clearLog { [DiagnosticsStore.shared clear]; self.items = @[]; [self.tableView reloadData]; }
@end
