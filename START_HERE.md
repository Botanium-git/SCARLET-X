# START HERE — Scarlet X 開発・引き継ぎの入口

> **新しいチャットや作業担当者は、コード変更前に必ずこのページを読む。** この文書は目次・プロジェクト目的・現在の優先順位・引き継ぎ手順を示す。全文の代用ではない。関連する一次資料・最新コード・ログを実際に確認する。

## 0. なぜ Scarlet X を作るのか（2026-11-09 ユーザー本人が明示）

- **iPhone 15 上の公式Xで、いいねやリポストが機能しない**ため、日常的に使える代替Xクライアントが必要。
- Scarlet X はそのための**独立したアプリ**。原作Xの完全再現自体が最優先の製品目的ではない。
- 開発中に毎日の基本操作ができないのは不便。**ホームタイムライン・DM・いいね・リポストの実用性を先に確保する**。
- 公式Xの表示決定プロセスの再現（文字サイズ計算、Core Text、Dynamic Type、Bio等）は捨てない。ただし **2026-11-09 時点で一時停止**し、通常利用の土台を優先する。
- 「公式Xと同じ画面配置」は絶対条件ではない。**ユーザーが意図的に変えた配置（プロフィールのボタンなど）を勝手に戻さない。**

## 1. 絶対に先に読む資料と用途

| 読む順 | 場所 | 内容 / 参照するタイミング |
| --- | --- | --- |
| 1 | **本ファイル `START_HERE.md`** | 製品の理由、優先順位、状況、他資料の入口 |
| 2 | [`Docs/ScarletXArchitectureAndHandoff.md`](Docs/ScarletXArchitectureAndHandoff.md) | 独立アプリ・WebKit通信・意図的なUI差異・表示研究を含む確定方針。**第3節の旧優先順位は本ファイルの2026-11-09更新で一時的に上書き** |
| 3 | [`Docs/ACTIVE_WORK.md`](Docs/ACTIVE_WORK.md) | **毎回更新する作業状況**。現行版、完成/未確認、次タスク、依存条件 |
| 4 | [`Docs/FEATURE_MAP.md`](Docs/FEATURE_MAP.md) | ホーム、DM、いいね、リポスト、プロフィールの実装担当と検証ポイント |
| 5 | [`Docs/CHANGELOG_DEV.md`](Docs/CHANGELOG_DEV.md) | 変更・試験・不具合・差し戻しの短い時系列。各テーマの開始/終了時に更新 |
| 6 | [`README.md`](README.md) | 起動、WebKitベースの初期構想、旧ビルド手順。**古い情報があるので現行ソースを優先** |
| 7 | [`UI/NativeProfileViewController.m`](UI/NativeProfileViewController.m), [`UI/NativeProfilePolish230.m`](UI/NativeProfilePolish230.m) | プロフィールBio・レイアウト。現在の実装と原作調査を混同しない |
| 8 | [`UI/NativeProfileDirectTable278.m`](UI/NativeProfileDirectTable278.m) | プロフィール投稿DirectTable。正常なレイアウト・画像・ページングを不用意に変更しない |
| 9 | [`Browser/BrowserViewController.m`](Browser/BrowserViewController.m), [`Browser/BrowserViewController+Navigation.m`](Browser/BrowserViewController+Navigation.m) | Webセッション、画面遷移、ブラウザ基盤。日常機能の変更前に確認 |
| 10 | [`Makefile`](Makefile), [`Resources/Info.plist`](Resources/Info.plist) | ビルド構成・アプリバージョンの事実確認 |

### 別リポジトリにある解析資料

- [Scarlet X Probe / `ANALYSIS_RECORD.md`](https://github.com/Botanium-git/SCARLET-X-Probe/blob/develop/ANALYSIS_RECORD.md) — X 12.38のBio、Mach-O、`xds_body`、文字計算、SXP調査。**この資料だけが製品全体の引き継ぎ先ではない**。
- [Development-record / OfficialXFindingsLedger](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXFindingsLedger.md) — 公式Xの調査台帳。
- [Development-record / OfficialXTextSizingDisassembly](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXTextSizingDisassembly.md) — 文字計測逆解析。
- [Development-record / OfficialXAnalysisStatus](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXAnalysisStatus.md) — 調査の到達点と未確認事項。
- Google Driveは実機診断ログの保管先。製品の引き継ぎ「入口」は原則としてGitHubに固定する。

## 2. 現在の実装方針（2026-11-09）

- **第1段階:** 既存の`WKWebView`・`WKWebsiteDataStore.defaultDataStore`・X Webセッションを維持し、ホームとDMの使いやすい切替導線を作る。通信/API契約が未確認のままネイティブGraphQL送信に切り替えない。
- **第2段階:** 本当にホーム/DMが表示され、いいね・リポスト・DM送受信が**サーバーへ反映されるか**をiPhone 15で確認する。ボタン押下だけで成功扱いにしない。
- **第3段階:** 必要に応じて表示部分をネイティブ化。取得/認証/状態/操作の責務を分離し、小さく移行する。
- **表示の原作再現:** 解析の成果を保持していったん停止。再開時は上記SXP記録と、現行SXソース、実際の公式Xバイナリを再確認する。

## 3. 変更前・変更後の必須手順

1. このページ → `ACTIVE_WORK.md` → 関連資料 → 最新`develop`ソースとSHAを読む。以前の会話の記憶だけで仕様を復元しない。
2. **事実 / 仮説 / 未確認**を区別。ユーザーが決めた仕様と調査の暫定案を混ぜない。
3. 一バージョン一テーマ、既存機能を残す。意図的UI変更を保持。プロフィールDirectTable、タブ、画像、ページングに無関係な変更をしない。
4. 変更のたび`CFBundleShortVersionString`と`CFBundleVersion`を更新する。ソース更新後のGitHub Actionsを確認する。**ビルド成功≠実機成功**。
5. 結果、コミット、Actions URL、実機検証の有無、残る課題を`ACTIVE_WORK.md`と`CHANGELOG_DEV.md`に残す。診断・原作解析は適切な`ANALYSIS_RECORD.md`へ追記する。
6. 正常実機版がある場合、復旧は**検証済みコミットへ差し戻す**。見かけ上同じものを新しい版として組み直さない。

## 4. 引き継ぎ時の短い確認チェック

- [ ] 本ファイルと `ACTIVE_WORK.md` を読んだ
- [ ] 現在の製品目的と優先順位を理解した
- [ ] `develop` HEAD、最新アプリ版、最新ビルド結果を再取得した
- [ ] 今回の関連ソース/記録/実機ログを読んだ
- [ ] 最後に実機成功した版と未検証版を区別した
- [ ] ユーザーの意図的なUI差異・既存機能を保護する
- [ ] 作業後、記録とリンクを更新した

**メモ:** READMEや古い引き継ぎ文書と矛盾した場合、勝手に統合せず、どの時点のユーザーの明示指示かを確認する。このファイルは時系列の最新決定の入口であって、古い解析データを抹消するものではない。
