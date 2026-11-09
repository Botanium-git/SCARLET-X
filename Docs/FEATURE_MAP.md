# Scarlet X — 機能別の実装場所と検証項目

> [START_HERE](../START_HERE.md) と [ACTIVE_WORK](ACTIVE_WORK.md) を先に読む。2026-11-09時点のコード確認に基づく。実機動作の推測ではない。

| 機能 | 現状・責務 | 主な参照先 | 実機で検証すること |
|---|---|---|---|
| ホーム/タイムライン | WebKitの既存`https://x.com/home`、表示カスタマイズあり。仮切替UIを追加予定/実装時は別途記録 | `Browser/BrowserViewController.m`, `Browser/BrowserViewController+Navigation.m`, `Scripts/DisplayScripts.m` | 読込、タブ切替、スクロール、ログイン保持 |
| いいね/リポスト | 現時点でSX側の独立したネイティブ操作成功処理は未検証。Webの操作を暫定利用 | `Browser/BrowserViewController.m`, `Browser/BrowserViewController+InteractionPolicy.m` | 操作してサーバーへ反映、再読込後も反映されるか、取り消し可否 |
| DM | WebKitと既存Xログインセッションを使う仮機能。ネイティブDM API契約は未確定 | `Browser/BrowserViewController.m`, `Browser/BrowserViewController+Navigation.m` | 受信一覧、会話表示、送信と相手への反映、画面復帰 |
| プロフィール | ネイティブUI、WebKit由来のAPI/状態を利用、カスタム配置あり | `UI/NativeProfileViewController.m`, `UI/NativeProfilePolish230.m`, `Browser/NativeProfileBridge.m`, `Browser/InternalProfileAPIBridge.m` | アカウント、Bio、表示、投稿切替、ページング |
| プロフィール投稿 | DirectTable、独自セル/画像・ページング・再描画補正 | `UI/NativeProfileDirectTable278.m`, `UI/NativeProfileTableTabReload280.m`, `Browser/NativeProfilePagination238.m` | 画像サイズ、セル再利用、順番、重複、読み込み |
| サイドメニュー | ネイティブメニュー、アカウント表示・切替、Web遷移 | `UI/NativeDrawerViewController.m`, `Browser/BrowserViewController.m` | 開閉、アカウント切替、リンク |
| 診断 | 明示的ログ収集、Settings、Drive連携 | `Diagnostics/`, `UI/SettingsViewController.m`, `UI/GoogleDriveSettingsController.m` | 秘密情報の扱い、記録/送信の成否 |
| 公式X表示式 | 原作再現は一時停止、既往成果維持 | `Docs/ScarletXArchitectureAndHandoff.md`, [SXP ANALYSIS_RECORD](https://github.com/Botanium-git/SCARLET-X-Probe/blob/develop/ANALYSIS_RECORD.md) | 後日再開。暫定固定値を公式の式と混同しない |

## 実装方針の注意

- ホーム/DMの「基本の仕組み」は **WebKitセッションを再利用する仮のUI導線** と **後でネイティブ化できる画面責務の区別** を意味する。未確認のDM APIエンドポイントや成功通知を捏造しない。
- 「いいね／リポストが動く」は画面上のアイコン変化だけでは成功判定しない。iPhone 15で再読み込み後の維持、別端末からの状態確認等を行う。
- NativeProfileの意図的なボタン配置変更は維持する。
