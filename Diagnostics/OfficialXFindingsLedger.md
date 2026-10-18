# 公式X v12.25 解析・発見事項台帳

目的: 過去の成果を失わず、個別の用語/IMP/トークンから検索できるようにする。**過去の報告を一律に確定扱いしない。**

## 現時点の検証対象
- 公式Xアプリ v12.25 IPA `com.atebits.Tweetie2_12.25_und3fined(1).ipa`
- SQLite `scarlet_macho(1).sqlite`: `binaries,strings,symbols,functions,imports,objc_methods`
- 索引済み: binary_id=1 `T1Twitter`、binary_id=2 `XAppLibraries`
- SQLiteのサイズやアドレスは収集時のファイルのもの。**IMPはファイルオフセット等と混同せず、ツール表現とbase addressを確認する。**

## 当ターン SQLite SQL 照会で確認した事項

### OX-001 — 投稿向けAttributedTextModel生成候補
**DB確認**: `T1Twitter` の `objc_methods` に
- selector `_t1_attributedTextModelForStatusViewModel:width:displayType:account:`
- `binary_id=1`, `imp=4227840` (hex `0x408300`), types `@48@0:8@16d24Q32@40`
がある。
**未確認**: 呼び出し元、生成したモデルの用途、本文行高への使用。

### OX-002 — サイズ計算に関係しそうなselector
**DB確認**: `T1Twitter` の `objc_methods` に
- `sizeThatFits:attributedText:`, imp `8463912` (hex `0x812628`)
- `layoutWithText:font:origin:width:outFrame:outContentHeight:`, imp `4816840` (hex `0x497FC8`)
- `_t1_quotedStatusCellHeightForStatus:account:width:layoutMetrics:withOptions:`, imp `83128` (hex `0x144B8`)
がある。
**未確認**: どれがタイムライン本文を計測するか。名前から決めつけない。

### OX-003 — 他のテキスト高さ候補
**DB確認**: `XAppLibraries` の `objc_methods` に `attributedTextModelHeightForOptions:` の複数レコード（例: `imp=9888708`）がある。
**未確認**: 投稿本文か、別画面か、同名メソッドのクラス所有者。SQLiteの `objc_methods` にはクラス名カラムがない。

### OX-004 — 外部参照と未特定の定義
**DB確認**: 両対象バイナリの `symbols` に `_OBJC_CLASS_$_TFNAttributedTextModel`、`_OBJC_CLASS_$_TFNSizeThatFitsHelper` は `*UND*` として記録されている。
`_CTLineGetTypographicBounds` も T1Twitter に `*UND*` として記録されている。
**解釈**: この2バイナリ内の定義を示すレコードではない。参照があるだけで使用経路は未確定。定義の所在はIPAのほかのMach-Oやフレームワークを追う必要がある。


### OX-005 — TFNクラス定義の所在をIPAから特定（2026-10-19）
**IPA実物から確認**: 公式X v12.25の `Payload/Twitter.app/Frameworks/XServiceLibraries.framework/XServiceLibraries` をIPAから展開して、`llvm-objdump --macho --syms` で確認。
- `_OBJC_CLASS_$_TFNAttributedTextModel`: `0x04422590`, `g O __DATA,__objc_data`
- `_OBJC_METACLASS_$_TFNAttributedTextModel`: `0x044225B8`
- `_OBJC_CLASS_$_TFNSizeThatFitsHelper`: `0x0442A3A8`, `g O __DATA,__objc_data`
- `_OBJC_METACLASS_$_TFNSizeThatFitsHelper`: `0x0442A380`
これは外部参照ではなく、上記Mach-Oにある定義シンボルを示す。以前のOX-004は *解析していた2バイナリでは未定義* という意味であり矛盾しない。
**まだ未確認**: 定義クラスの実装メソッドと投稿本文計測への接続。


### OX-006 — XServiceLibrariesを独立索引化（2026-10-19）
**IPA + 既存インデクサから確認**: `SCARLET_MachO_Indexer` の `build --framework XServiceLibraries` で、82.0 MBのMach-Oから `strings=446543`、`objc_methods=25530` をSQLiteへ追加インデックス化した（独立DB）。既存の2バイナリDBに統合したわけではない。

**SQLiteの `objc_methods` で確認した実装候補**:
- `sizeThatFitsSize:layoutMetrics:` — IMP `0x2FF2350`、戻り値 `CGSize`
- `sizeThatFitsSize:layoutMetrics:displayedLines:` — IMP `0x2FF23B0`、戻り値 `CGSize`
- `_t1_textModelForAttributedString:` — IMP `0xDD1E5C`
- `initWithString:font:lineSpacing:` — IMP `0xCA1244`
- `initWithString:font:alignment:lineBreakMode:paragraphSpacing:lineHeight:lineSpacing:` — IMP `0xCA12D4`
- `_setFont:alignment:lineBreakMode:paragraphSpacing:lineHeight:lineSpacing:writingDirection:` — IMP `0xCA1DCC`

**未確認**: これらのIMPの所有クラス、具体的な逆アセンブル動作、タイムライン本文の呼び出し経路。メソッド名だけでは使用箇所を断定できない。

**再現手順**:
```bash
python3 scarlet_macho_index.py build Twitter.ipa -o xservice.sqlite --framework XServiceLibraries
python3 ResearchTools/macho_db_search.py --db xservice.sqlite --query sizeThatFits --binary XServiceLibraries
```

## 過去の会話の解析報告（当ターン再検証は未実施）

### OX-H01 — フォントトークン
2026-10-12〜13の解析会話で、token 6 = `xds_subtext2`、token 8 = `xds_subtext2Bold` と報告されていた。フォロー数関連の表示ではそれぞれSF Regular/Semibold 11pt、基準13pt、行高13.127pt、Chirp OFFと報告。
- `fontForToken:` IMP `0x369F0C` との当時の報告。
- フォント名や数値は**対象UIがフォロー数付近**であり、投稿本文の仕様へ一般化しない。
- 値とアドレスは**過去報告**。今回のSQLiteで同アドレスの所有実装まで再検証したわけではない。

### OX-H02 — フォロー数の属性付き文字列
2026-10-12〜13の会話で、生成IMP `0x299068`、`NSParagraphStyle.lineSpacing=4.0`、font/color/paragraph attributes、`TFNAttributedTextView`・`TFNAttributedTextModel`、`setTextModel:` `0x134EEC0`、`setAttributedString:` `0x1336820` が報告された。
**重要**: フォロー数文脈の過去報告であり、タイムライン本文に4ptの行間が適用される根拠ではない。

### OX-H03 — Dynamic Type補正
2026-10-12〜13の会話で以下が報告された。
- `fontSizeWithBaselineFontSize:contentSizeCategory:contentSizeModifier:windowSize:` IMP `0x244F2F4`、補助 `0x244ED5C`、`frinta` 丸め。
- 12カテゴリ補正: `−2, −1, 0, 0, +1, +3, +6, +10, +15, +20, +25, +30`。
- 設定キー `ios_ui_font_size_ignore_device_width_enabled`。
- `tfn_setContentFontSize:minimum:maximum:maximumDynamic:`、基準Bの初期14pt/最大17ptという解析報告もあるが、runtime Bや境界条件は未確定との注記があった。
**重要**: 当時報告された条件が現在の端末・全テキストに適用されるとは決めない。

### OX-H04 — フォロー数スタイルの暫定式
過去報告の暫定式: 通常のtoken 6/8のサイズ `S=min(B,17)-2`。上記 H03 と同様に、Bの実行時値やアクセシビリティ分岐は未確定。

## Scarlet X の計測（公式Xとは別）

### SX-001 — Core Text比較実験
v1.4.166 の `ScarletX_CoreText_2026-10-19_083121.json` の新形式100件:
- legacy と実験Core Text高さが一致83件、不一致17件。
- 差: +5pt×5、+6pt×10、+11pt×1、+18pt×1。
- 新ログ `baselineExcess`、`firstAscent`、`lastDescent`。先頭行/末尾行のglyph extentとベースライン間隔を追跡。
- **これは自作アプリ内の2種類の方式の差。公式Xとの差の実測値ではない。**

### SX-002 — 変更の制約
ユーザー確定: 公式Xの仕組みを可能な範囲で解析して再現する。推測で表示・行高を変更しない。DirectTable既存仕様を維持。
v1.4.167 でユーザー指示によりアプリ内更新UIと実装ファイルを削除。Sources/自動リリースは維持。

## 未解決 / 優先順位
1. XServiceLibraries の TFNAttributedTextModel / TFNSizeThatFitsHelper のクラスメソッド・参照を解析。
2. OX-001〜003のオーナークラスと呼び出し先を実コードで確認。
3. 公式Xの**タイムライン本文**に適用するフォント、属性、ベースライン、計測ルールを特定。
4. 同一投稿・同一デバイス・同一有効幅で実測し、差があれば反証可能な形で記録。
5. 過去の全チャット・未回収資料にはまだ未登録の発見がありうる。追加時は一次資料と照合。

## 検索SQL例
```sql
SELECT binary_id, selector, types, imp
FROM objc_methods
WHERE selector LIKE '%attributedTextModel%'
ORDER BY binary_id, imp;

SELECT binary_id, kind, name
FROM symbols
WHERE name LIKE '%TFNSizeThatFitsHelper%';
```
