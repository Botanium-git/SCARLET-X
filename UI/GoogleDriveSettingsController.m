#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

// First-stage Google OAuth callback probe. No tokens are persisted or uploaded.
static NSString * const SXGoogleClientID = @"336218902468-g2t9ha7h9jhfckilh1l8k2k1gl64sltr.apps.googleusercontent.com";
static NSString * const SXGoogleScheme = @"com.googleusercontent.apps.336218902468-g2t9ha7h9jhfckilh1l8k2k1gl64sltr";
static NSString *SXBase64URL(NSData *data) {
    NSString *s = [data base64EncodedStringWithOptions:0];
    return [[[s stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}
static NSString *SXRandomURLSafe(NSUInteger bytes) {
    NSMutableData *data = [NSMutableData dataWithLength:bytes];
    if (SecRandomCopyBytes(kSecRandomDefault, bytes, data.mutableBytes) != errSecSuccess) return nil;
    return SXBase64URL(data);
}
@interface SXGoogleDriveSettingsController : UITableViewController <ASWebAuthenticationPresentationContextProviding>
@property(nonatomic,strong) ASWebAuthenticationSession *session;
@property(nonatomic,copy) NSString *expectedState;
@property(nonatomic,copy) NSString *pkceVerifier;
@property(nonatomic,copy) NSString *status;
@end
@implementation SXGoogleDriveSettingsController
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Google Drive連携"; self.status=@"未接続（認証経路の検証段階）"; [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"google"]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 2; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"最初にLiveContainerでGoogle認証がScarlet Xへ戻るか確認します。認証コードやトークンは保存・送信しません。Driveアップロードは認証経路の実機確認後に実装します。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c=[tableView dequeueReusableCellWithIdentifier:@"google" forIndexPath:indexPath];
    c.accessoryView=nil; c.accessoryType=UITableViewCellAccessoryNone; c.imageView.image=nil;
    c.textLabel.numberOfLines=0;
    if (indexPath.row==0) { c.textLabel.text=self.status; c.imageView.image=[UIImage systemImageNamed:@"checkmark.shield"]; }
    else { c.textLabel.text=@"Googleで認証をテスト"; c.imageView.image=[UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"]; c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    return c;
}
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session { return self.view.window; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row==1) [self startAuth];
}
- (void)showStatus:(NSString *)status { self.status=status; [self.tableView reloadData]; }
- (void)startAuth {
    if (self.session) return;
    NSString *verifier=SXRandomURLSafe(32), *state=SXRandomURLSafe(24);
    if (!verifier || !state) { [self showStatus:@"安全な乱数を作成できませんでした"]; return; }
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    NSData *verifierData=[verifier dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256(verifierData.bytes, (CC_LONG)verifierData.length, hash);
    NSString *challenge=SXBase64URL([NSData dataWithBytes:hash length:sizeof(hash)]);
    NSString *redirect=[NSString stringWithFormat:@"%@:/oauth2redirect/google",SXGoogleScheme];
    NSURLComponents *u=[NSURLComponents componentsWithString:@"https://accounts.google.com/o/oauth2/v2/auth"];
    u.queryItems=@[
      [NSURLQueryItem queryItemWithName:@"client_id" value:SXGoogleClientID],
      [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
      [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
      [NSURLQueryItem queryItemWithName:@"scope" value:@"https://www.googleapis.com/auth/drive.file"],
      [NSURLQueryItem queryItemWithName:@"code_challenge" value:challenge],
      [NSURLQueryItem queryItemWithName:@"code_challenge_method" value:@"S256"],
      [NSURLQueryItem queryItemWithName:@"state" value:state],
      [NSURLQueryItem queryItemWithName:@"access_type" value:@"offline"]
    ];
    self.pkceVerifier=verifier; self.expectedState=state;
    __weak typeof(self) weakSelf=self;
    ASWebAuthenticationSession *auth=[[ASWebAuthenticationSession alloc] initWithURL:u.URL callbackURLScheme:SXGoogleScheme completionHandler:^(NSURL *callback, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self=weakSelf;
            if (!self) return;
            self.session=nil;
            if (error) { [self showStatus:[NSString stringWithFormat:@"認証の戻りに失敗: %@ (%ld)",error.domain,(long)error.code]]; return; }
            NSURLComponents *c=[NSURLComponents componentsWithURL:callback resolvingAgainstBaseURL:NO];
            NSString *gotState=nil,*code=nil,*oauthError=nil;
            for (NSURLQueryItem *q in c.queryItems) {
                if ([q.name isEqualToString:@"state"]) gotState=q.value;
                if ([q.name isEqualToString:@"code"]) code=q.value;
                if ([q.name isEqualToString:@"error"]) oauthError=q.value;
            }
            if (![callback.scheme isEqualToString:SXGoogleScheme] || ![gotState isEqualToString:self.expectedState]) {
                [self showStatus:@"認証応答の検証に失敗（state不一致）"];
            } else if (oauthError) {
                [self showStatus:[NSString stringWithFormat:@"Google認証エラー: %@",oauthError]];
            } else if (code.length) {
                [self showStatus:@"認証コールバック成功！ 次の段階で安全なトークン保存・Drive送信を実装できます。"];
            } else {
                [self showStatus:@"認証コードがありません"];
            }
            self.expectedState=nil; self.pkceVerifier=nil;
        });
    }];
    auth.presentationContextProvider=self;
    self.session=auth;
    [self showStatus:@"Google認証を開始中…"];
    if (![auth start]) { self.session=nil; self.expectedState=nil; self.pkceVerifier=nil; [self showStatus:@"認証画面を開始できませんでした"]; }
}
@end
@implementation NSObject (SXGoogleDriveSettingsEntry)
@end
UIViewController *SXCreateGoogleDriveSettingsController(void) { return [SXGoogleDriveSettingsController new]; }
