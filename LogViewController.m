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
- (void)clearLog { [DiagnosticsStore.shared clear]; self.items = @[]; [self.tableView reloadData]; }
@end
