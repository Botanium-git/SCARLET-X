#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import "../Diagnostics/DiagnosticsStore.h"

static NSString * const SXGoogleClientID=@"336218902468-g2t9ha7h9jhfckilh1l8k2k1gl64sltr.apps.googleusercontent.com";
static NSString * const SXGoogleScheme=@"com.googleusercontent.apps.336218902468-g2t9ha7h9jhfckilh1l8k2k1gl64sltr";
static NSString * const SXGoogleKeychainService=@"com.scarletx.google-drive-oauth";
static NSString * const SXGoogleKeychainAccount=@"drive.file";
static NSString *SXBase64URL(NSData *data) {
 NSString *s=[data base64EncodedStringWithOptions:0];
 return [[[s stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}
static NSString *SXRandomURLSafe(NSUInteger length) {
 NSMutableData *data=[NSMutableData dataWithLength:length];
 return SecRandomCopyBytes(kSecRandomDefault,length,data.mutableBytes)==errSecSuccess?SXBase64URL(data):nil;
}
static NSMutableDictionary *SXCredentialQuery(void) {
 return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
           (__bridge id)kSecAttrService:SXGoogleKeychainService,
           (__bridge id)kSecAttrAccount:SXGoogleKeychainAccount} mutableCopy];
}
static NSDictionary *SXReadCredential(void) {
 NSMutableDictionary *q=SXCredentialQuery();
 q[(__bridge id)kSecReturnData]=@YES;
 q[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
 CFTypeRef result=NULL;
 OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)q,&result);
 if (status!=errSecSuccess || !result) return nil;
 NSData *data=CFBridgingRelease(result);
 id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
 return [value isKindOfClass:NSDictionary.class]?value:nil;
}
static BOOL SXSaveCredential(NSDictionary *credential) {
 NSData *data=[NSJSONSerialization dataWithJSONObject:credential options:0 error:nil];
 if (!data) return NO;
 NSMutableDictionary *q=SXCredentialQuery();
 SecItemDelete((__bridge CFDictionaryRef)q);
 q[(__bridge id)kSecValueData]=data;
 q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
 return SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess;
}
static void SXDeleteCredential(void) { SecItemDelete((__bridge CFDictionaryRef)SXCredentialQuery()); }
static NSString *SXFormEscape(NSString *s) {
 NSMutableCharacterSet *allowed=[NSCharacterSet URLQueryAllowedCharacterSet].mutableCopy;
 [allowed removeCharactersInString:@"&+=?"];
 return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed]?:@"";
}
static NSData *SXFormData(NSDictionary<NSString *,NSString *> *values) {
 NSMutableArray *pairs=[NSMutableArray array];
 for (NSString *key in values) [pairs addObject:[NSString stringWithFormat:@"%@=%@",SXFormEscape(key),SXFormEscape(values[key])]];
 return [[pairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
}
typedef void (^SXAPICompletion)(NSDictionary *result, NSError *error);
static void SXRequest(NSURLRequest *request,SXAPICompletion finish) {
 [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  id obj=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
  NSDictionary *json=[obj isKindOfClass:NSDictionary.class]?obj:@{};
  NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
  if (!error && (status<200 || status>=300)) {
   NSString *message=[json[@"error_description"] isKindOfClass:NSString.class]?json[@"error_description"]:[json[@"error"] description];
   error=[NSError errorWithDomain:@"ScarletXGoogleDrive" code:status userInfo:@{NSLocalizedDescriptionKey:message.length?message:[NSString stringWithFormat:@"HTTP %ld",(long)status]}];
  }
  dispatch_async(dispatch_get_main_queue(),^{ finish(json,error); });
 }] resume];
}
static NSURLRequest *SXJSONRequest(NSString *url,NSString *method,NSString *token,NSDictionary *body) {
 NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
 r.HTTPMethod=method;
 [r setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
 if (body) {
  [r setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
  r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
 }
 return r;
}
@interface SXGoogleDriveSettingsController : UITableViewController <ASWebAuthenticationPresentationContextProviding>
@property(nonatomic,strong) ASWebAuthenticationSession *session;
@property(nonatomic,copy) NSString *expectedState;
@property(nonatomic,copy) NSString *pkceVerifier;
@property(nonatomic,copy) NSString *status;
@property(nonatomic,assign) BOOL busy;
@end
@implementation SXGoogleDriveSettingsController
- (void)viewDidLoad {
 [super viewDidLoad]; self.title=@"Google Drive連携";
 self.status=SXReadCredential()?@"接続済み（Driveの利用は未確認）":@"未接続";
 [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"google"];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 4; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
 return @"診断ログ送信は手動です。Core Text本文高さ比較の数値のみをGoogle DriveのScarletX/Diagnosticsへ保存します。投稿本文、URL、Cookie、Xの認証情報は送信しません。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell *c=[tableView dequeueReusableCellWithIdentifier:@"google" forIndexPath:indexPath];
 c.accessoryView=nil;c.accessoryType=UITableViewCellAccessoryNone;c.imageView.image=nil;c.textLabel.numberOfLines=0;
 NSArray *titles=@[self.status?:@"未接続",@"Googleアカウントで接続",@"Core Text比較ログをDriveへ送信",@"Google Driveの接続を解除"];
 c.textLabel.text=titles[indexPath.row];
 NSArray *icons=@[@"checkmark.shield",@"person.crop.circle.badge.checkmark",@"arrow.up.doc",@"person.crop.circle.badge.xmark"];
 c.imageView.image=[UIImage systemImageNamed:icons[indexPath.row]];
 if(indexPath.row==1 || indexPath.row==2) c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
 if(indexPath.row==3)c.textLabel.textColor=UIColor.systemRedColor;else c.textLabel.textColor=UIColor.labelColor;
 return c;
}
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session { return self.view.window; }
- (void)showStatus:(NSString *)message { self.status=message;[self.tableView reloadData]; }
- (void)finishBusy:(NSString *)message { self.busy=NO;[self showStatus:message]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 [tableView deselectRowAtIndexPath:indexPath animated:YES];
 if(self.busy)return;
 if(indexPath.row==1)[self startAuth];
 else if(indexPath.row==2)[self uploadLog];
 else if(indexPath.row==3)[self confirmDisconnect];
}
- (void)confirmDisconnect {
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Google Driveの接続を解除" message:@"この端末の認証情報を削除します。Drive上に送信済みのファイルは削除しません。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:@"解除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action){SXDeleteCredential();[self showStatus:@"未接続"]; }]];
 [self presentViewController:a animated:YES completion:nil];
}
- (void)startAuth {
 if(self.session || self.busy)return;
 NSString *verifier=SXRandomURLSafe(32),*state=SXRandomURLSafe(24);
 if(!verifier || !state){[self showStatus:@"安全な乱数を作成できませんでした"];return;}
 unsigned char hash[CC_SHA256_DIGEST_LENGTH];NSData *v=[verifier dataUsingEncoding:NSUTF8StringEncoding];
 CC_SHA256(v.bytes,(CC_LONG)v.length,hash);
 NSString *redirect=[NSString stringWithFormat:@"%@:/oauth2redirect/google",SXGoogleScheme];
 NSURLComponents *u=[NSURLComponents componentsWithString:@"https://accounts.google.com/o/oauth2/v2/auth"];
 u.queryItems=@[
 [NSURLQueryItem queryItemWithName:@"client_id" value:SXGoogleClientID],
 [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
 [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
 [NSURLQueryItem queryItemWithName:@"scope" value:@"https://www.googleapis.com/auth/drive.file"],
 [NSURLQueryItem queryItemWithName:@"code_challenge" value:SXBase64URL([NSData dataWithBytes:hash length:sizeof(hash)])],
 [NSURLQueryItem queryItemWithName:@"code_challenge_method" value:@"S256"],
 [NSURLQueryItem queryItemWithName:@"state" value:state],
 [NSURLQueryItem queryItemWithName:@"access_type" value:@"offline"],
 [NSURLQueryItem queryItemWithName:@"prompt" value:@"consent"]
 ];
 self.expectedState=state;self.pkceVerifier=verifier;self.busy=YES;
 __weak typeof(self) weakSelf=self;
 ASWebAuthenticationSession *auth=[[ASWebAuthenticationSession alloc] initWithURL:u.URL callbackURLScheme:SXGoogleScheme completionHandler:^(NSURL *callback,NSError *error){
 dispatch_async(dispatch_get_main_queue(),^{
  __strong typeof(weakSelf) self=weakSelf;if(!self)return;
  self.session=nil;
  if(error){self.expectedState=nil;self.pkceVerifier=nil;[self finishBusy:[NSString stringWithFormat:@"認証失敗: %@ (%ld)",error.domain,(long)error.code]];return;}
  NSURLComponents *c=[NSURLComponents componentsWithURL:callback resolvingAgainstBaseURL:NO];
  NSString *gotState=nil,*code=nil,*oauthError=nil;
  for(NSURLQueryItem *q in c.queryItems){
   if([q.name isEqualToString:@"state"])gotState=q.value;
   if([q.name isEqualToString:@"code"])code=q.value;
   if([q.name isEqualToString:@"error"])oauthError=q.value;
  }
  if(![callback.scheme isEqualToString:SXGoogleScheme] || ![gotState isEqualToString:self.expectedState]){
   self.pkceVerifier=nil;self.expectedState=nil;[self finishBusy:@"認証応答の検証に失敗"];return;
  }
  if(oauthError || !code.length){self.pkceVerifier=nil;self.expectedState=nil;[self finishBusy:oauthError?:@"認証コードがありません"];return;}
  NSString *pkce=self.pkceVerifier;
  self.pkceVerifier=nil;self.expectedState=nil;
  [self exchangeCode:code verifier:pkce redirect:redirect];
 });
 }];
 auth.presentationContextProvider=self;self.session=auth;
 [self showStatus:@"Google認証中…"];
 if(![auth start]){self.session=nil;self.busy=NO;self.pkceVerifier=nil;self.expectedState=nil;[self showStatus:@"認証画面を開始できませんでした"];}
}
- (void)requestToken:(NSDictionary<NSString *,NSString *> *)parameters completion:(SXAPICompletion)completion {
 NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
 r.HTTPMethod=@"POST";[r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
 r.HTTPBody=SXFormData(parameters);SXRequest(r,completion);
}
- (void)exchangeCode:(NSString *)code verifier:(NSString *)verifier redirect:(NSString *)redirect {
 [self showStatus:@"認証情報を安全に保存中…"];
 [self requestToken:@{@"client_id":SXGoogleClientID,@"code":code,@"code_verifier":verifier,@"redirect_uri":redirect,@"grant_type":@"authorization_code"} completion:^(NSDictionary *json,NSError *error){
  NSString *access=[json[@"access_token"] isKindOfClass:NSString.class]?json[@"access_token"]:nil;
  NSString *refresh=[json[@"refresh_token"] isKindOfClass:NSString.class]?json[@"refresh_token"]:nil;
  if(error || !access.length || !refresh.length){[self finishBusy:[NSString stringWithFormat:@"Google接続に失敗: %@",error.localizedDescription?:@"必要なトークンが取得できません"]];return;}
  NSDictionary *credential=@{@"access_token":access,@"refresh_token":refresh,@"expires_at":@(NSDate.date.timeIntervalSince1970+[json[@"expires_in"] doubleValue]-60)};
  [self finishBusy:SXSaveCredential(credential)?@"接続済み（Google Driveへの送信が可能）":@"Keychainへの保存に失敗しました"];
 }];
}
- (void)withAccessToken:(void (^)(NSString *token,NSError *error))done {
 NSDictionary *cred=SXReadCredential();NSString *access=cred[@"access_token"],*refresh=cred[@"refresh_token"];
 if(!refresh.length){done(nil,[NSError errorWithDomain:@"ScarletXGoogleDrive" code:401 userInfo:@{NSLocalizedDescriptionKey:@"Googleアカウントを接続してください"}]);return;}
 if(access.length && [cred[@"expires_at"] doubleValue]>NSDate.date.timeIntervalSince1970){done(access,nil);return;}
 [self requestToken:@{@"client_id":SXGoogleClientID,@"refresh_token":refresh,@"grant_type":@"refresh_token"} completion:^(NSDictionary *json,NSError *error){
  NSString *updated=[json[@"access_token"] isKindOfClass:NSString.class]?json[@"access_token"]:nil;
  if(error || !updated.length){done(nil,error?:[NSError errorWithDomain:@"ScarletXGoogleDrive" code:401 userInfo:@{NSLocalizedDescriptionKey:@"再認証が必要です"}]);return;}
  NSDictionary *newCredential=@{@"access_token":updated,@"refresh_token":refresh,@"expires_at":@(NSDate.date.timeIntervalSince1970+[json[@"expires_in"] doubleValue]-60)};
  if(!SXSaveCredential(newCredential)){done(nil,[NSError errorWithDomain:@"ScarletXGoogleDrive" code:500 userInfo:@{NSLocalizedDescriptionKey:@"Keychainの更新に失敗しました"}]);return;}
  done(updated,nil);
 }];
}
- (void)findOrCreateFolder:(NSString *)name parent:(NSString *)parent token:(NSString *)token completion:(void (^)(NSString *folderID,NSError *error))done {
 NSString *escapedName=[name stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
 NSString *q=[NSString stringWithFormat:@"name = '%@' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and '%@' in parents",escapedName,parent?:@"root"];
 NSURLComponents *c=[NSURLComponents componentsWithString:@"https://www.googleapis.com/drive/v3/files"];
 c.queryItems=@[[NSURLQueryItem queryItemWithName:@"q" value:q],[NSURLQueryItem queryItemWithName:@"fields" value:@"files(id,name),nextPageToken"],[NSURLQueryItem queryItemWithName:@"page_size" value:@"100"]];
 SXRequest(SXJSONRequest(c.URL.absoluteString,@"GET",token,nil),^(NSDictionary *json,NSError *error){
  if(error){done(nil,error);return;}
  NSArray *files=[json[@"files"] isKindOfClass:NSArray.class]?json[@"files"]:@[];
  NSString *found=[files.firstObject isKindOfClass:NSDictionary.class]?files.firstObject[@"id"]:nil;
  if(found.length){done(found,nil);return;}
  NSDictionary *body=@{@"name":name,@"mimeType":@"application/vnd.google-apps.folder",@"parents":@[parent?:@"root"]};
  SXRequest(SXJSONRequest(@"https://www.googleapis.com/drive/v3/files?fields=id", @"POST",token,body),^(NSDictionary *result,NSError *createError){
   NSString *folder=[result[@"id"] isKindOfClass:NSString.class]?result[@"id"]:nil;
   done(folder,createError?:(!folder.length?[NSError errorWithDomain:@"ScarletXGoogleDrive" code:500 userInfo:@{NSLocalizedDescriptionKey:@"フォルダIDを取得できません"}]:nil));
  });
 });
}
- (void)uploadLog {
 if(self.busy)return;
 NSMutableArray *safe=[NSMutableArray array];
 for(NSDictionary *entry in [DiagnosticsStore shared].diagnosticEntries){
  if(![entry[@"title"] isEqual:@"Core Text本文高さ比較"])continue;
  NSString *detail=[entry[@"detail"] isKindOfClass:NSString.class]?entry[@"detail"]:@"";
  // Accept only numerical measurements, never arbitrary log text or URLs.
  NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"^sample=[0-9]+ chars=[0-9]+ width=[0-9.]+ font=[0-9.]+ lines=[0-9]+ legacy=[0-9.]+ coreText=[0-9.]+ delta=[-0-9.]+$" options:0 error:nil];
  if([pattern numberOfMatchesInString:detail options:0 range:NSMakeRange(0,detail.length)]!=1)continue;
  [safe addObject:@{@"date":entry[@"date"]?:@0,@"detail":detail}];
 }
 if(!safe.count){[self showStatus:@"送信対象のCore Text比較ログがありません"];return;}
 NSDictionary *payload=@{@"format":@"ScarletXCoreTextCompare",@"version":@1,@"appVersion":NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"",@"exportedAt":@(NSDate.date.timeIntervalSince1970),@"entries":safe};
 NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
 if(!data){[self showStatus:@"送信用JSONの作成に失敗しました"];return;}
 self.busy=YES;[self showStatus:[NSString stringWithFormat:@"%lu件の比較ログを送信中…",(unsigned long)safe.count]];
 [self withAccessToken:^(NSString *token,NSError *error){
  if(error){[self finishBusy:error.localizedDescription];return;}
  [self findOrCreateFolder:@"ScarletX" parent:@"root" token:token completion:^(NSString *rootID,NSError *folderError){
   if(folderError){[self finishBusy:folderError.localizedDescription];return;}
   [self findOrCreateFolder:@"Diagnostics" parent:rootID token:token completion:^(NSString *folderID,NSError *childError){
    if(childError){[self finishBusy:childError.localizedDescription];return;}
    [self uploadData:data folder:folderID token:token count:safe.count];
   }];
  }];
 }];
}
- (void)uploadData:(NSData *)data folder:(NSString *)folder token:(NSString *)token count:(NSUInteger)count {
 NSDateFormatter *formatter=[NSDateFormatter new];formatter.dateFormat=@"yyyy-MM-dd_HHmmss";
 NSString *filename=[NSString stringWithFormat:@"ScarletX_CoreText_%@.json",[formatter stringFromDate:NSDate.date]];
 NSDictionary *meta=@{@"name":filename,@"mimeType":@"application/json",@"parents":@[folder]};
 NSData *metaData=[NSJSONSerialization dataWithJSONObject:meta options:0 error:nil];
 NSString *boundary=[@"SXDrive" stringByAppendingString:SXRandomURLSafe(12)?:@"Boundary"];
 NSMutableData *body=[NSMutableData data];
 [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
 [body appendData:metaData];
 [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\nContent-Type: application/json\r\n\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
 [body appendData:data];
 [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
 NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name"]];
 r.HTTPMethod=@"POST";[r setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
 [r setValue:[NSString stringWithFormat:@"multipart/related; boundary=%@",boundary] forHTTPHeaderField:@"Content-Type"];
 r.HTTPBody=body;
 SXRequest(r,^(NSDictionary *json,NSError *error){
  NSString *fileID=[json[@"id"] isKindOfClass:NSString.class]?json[@"id"]:nil;
  if(error || !fileID.length){[self finishBusy:[NSString stringWithFormat:@"送信失敗: %@",error.localizedDescription?:@"ファイルIDがありません"]];return;}
  [self finishBusy:[NSString stringWithFormat:@"Google Driveへ送信成功（%lu件）\nScarletX/Diagnostics/%@",(unsigned long)count,filename]];
 });
}
@end
UIViewController *SXCreateGoogleDriveSettingsController(void) { return [SXGoogleDriveSettingsController new]; }
