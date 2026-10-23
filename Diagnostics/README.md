# SCARLET-X / 公式X解析 知識索引

**最初にこのファイルを開くこと。** 生データ、過去の解析報告、現在の確認済み仕様を混同しない。

## 参照順序
1. [公式Xの発見事項・証拠台帳](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXFindingsLedger.md) — これまでの調査で見つかった候補、過去の報告、今回のSQLite照合結果。IDで検索できる。
2. [公式XとScarlet Xの状態整理](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXAnalysisStatus.md) — 既知と未解決、一次資料。
3. [同文面比較プロトコル](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/CoreTextOfficialComparison.md) — 実機比較をする段階の手順。
4. SQLite生索引（ユーザー保持の `scarlet_macho(1).sqlite`）— class/selector/function address を検索。
5. 公式X v12.25 IPA（ユーザー保持 `com.atebits.Tweetie2_12.25_und3fined(1).ipa`）— 定義やコードの裏付けを調べる一次資料。
6. Scarlet X 実機診断（Google Drive `ScarletX/Diagnostics`）— 再現・比較の測定結果。ファイルとアプリバージョンを必ず特定。

## 信頼区分
- **DB確認**: 今回のSQLiteへのSQL照会でレコードを確認。メソッド名の存在 ≠ その処理が投稿本文に使われる証拠。
- **過去報告**: 過去の調査会話に結論/数値が記録されている。今回の同じIPA/逆アセンブルで再検証したとは限らない。
- **Scarlet X実測**: 自作診断ログで確かめた数値。公式Xの実測ではない。
- **仮説 / 未確認**: 成立を確認できていない項目。

## 今後の運用
- 新しい結論を得たらLedgerに ID / 対象 / 事実 / 根拠（ファイル・アドレス・ログ・コミット）/ 確度 / 未解決点を追加。
- 以前の結論に矛盾が出た場合、元の報告を黙って削除せず追記で更新。
- 「公式Xで測定済み」という表現は、公式アプリの実測証拠がある場合だけ使う。
- 以前の会話すべてを機械的に回収したわけではない。判明事項の漏れは追加していく。

## 2026-10-19 逆アセンブル再検証
- [Core Textサイズ計算・未解決スタブの解決](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXTextSizingDisassembly.md) — OX-011〜014。命令・丸め精度・最大行数・未確認範囲。
- [生命令・クラスメソッド全件](https://github.com/Botanium-git/Development-record/blob/main/SCARLET-X/OfficialXResearch/OfficialXTextSizingEvidence.txt) — 元Mach-Oのhash、アドレス、命令バイト、セレクタ参照。
