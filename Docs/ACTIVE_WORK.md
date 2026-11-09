# ACTIVE WORK — 現在地（必ず毎回更新）

最終記入: 2026-11-09 / branch: `develop`

## 目的と優先順位
**元の目的:** iPhone 15の公式Xでいいね・リポストが機能しないため、日常用の独立クライアントScarlet Xが必要。

**現在の最優先:** ホーム/タイムライン、DM、いいね、リポストを普段使える状態にする。原作Xの文字表示計算式の追跡は一時停止。将来再開する。

**必読:** [START_HERE](../START_HERE.md) → [FEATURE_MAP](FEATURE_MAP.md) → [ScarletXArchitectureAndHandoff](ScarletXArchitectureAndHandoff.md)。今回のタスクに関係する実ソースも必ず読む。

## 事前確認で分かっている状態（2026-11-09）
- `Browser/BrowserViewController.m`で1つの`WKWebView`を生成し、`WKWebsiteDataStore.defaultDataStore`でログイン状態を維持する設計。
- `Browser/BrowserViewController+Navigation.m`には`goHome`、`loadURL:reason:`が存在し、ホームURLは`https://x.com/home`。
- `Scripts/DisplayScripts.m`にWeb版の表示オプション。
- DMのネイティブ取得・送信API、独立ネイティブタイムラインは現行コードに実装済みと確認できていない。まずWeb版経由の仮機能を作る。
- `Resources/Info.plist`の確認済み既存版は **v1.4.170 / build 352**（作業後に再検証する）。
- **最終実機成功バージョン:** 現時点の記録だけでは確定できない。ActionsのSuccessを実機成功と呼ばない。

## 今回の計画・進捗
1. [x] 製品目的と新しい優先順位の確認。旧資料の扱いを確認。
2. [x] `START_HERE.md`新設、機能マップ/作業状況の独立化。
3. [ ] WebKitセッションを使うホーム/DMへの仮切替導線を実装（実際のコミット/版は作業終了時に追記）。
4. [ ] GitHub Actionsの最新ビルド結果を確認。
5. [ ] **iPhone 15の実機確認待ち**（DM画面到達、メッセージ送信、タイムラインいいね・リポスト、反映/取り消し）。

## リスク・確認事項
- `https://x.com/messages` はDMのWebページとして利用する想定。現行のユーザー環境で正常に表示できるかは未確認。
- 最初の仮実装はWeb版の機能を利用。独自のネイティブGraphQL取得・操作を完了したとは言わない。
- フォントの再現は未完成。`v1.4.170` Bioサイズは固定カテゴリ対応で、本家`xds_body`式の移植ではない。
- SXP/原作Xの解析は[Probe ANALYSIS_RECORD](https://github.com/Botanium-git/SCARLET-X-Probe/blob/develop/ANALYSIS_RECORD.md)に継続記録。SXの日常利用の開発と混ぜない。
