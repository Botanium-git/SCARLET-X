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


### OX-007 — SQLite IMP address caveat (2026-10-19)
**Mach-O section headers directly verified**: `XServiceLibraries` has `__TEXT,__text` at `0x4000..0x2ECC4E4`; `__TEXT,__objc_methlist` at `0x2F63D30..0x30156EC`. Indexed entries such as `sizeThatFitsSize:layoutMetrics:` (`objc_methods.imp=0x2FF2350`) and `sizeThatFitsSize:layoutMetrics:displayedLines:` (`0x2FF23B0`) are **inside `__objc_methlist`, NOT executable `__text`**. Accordingly the numeric `imp` column cannot be trusted as a method implementation PC without independent validation. Earlier OX-006 descriptions of these entries as implementation addresses must be read as index-stored values, not confirmed code targets. Root cause in indexer and scope of affected records not yet established. Disassembly or call graph inference from these specific stored `imp` values is invalid.


### OX-008 — IMPの実行領域検証と独立DB生成（2026-10-19）
**実物Mach-O・SQLiteによる再検証**: XServiceLibraries の `objc_methods` 25,530件のうち、格納された `imp` が実行属性のあるMach-Oセクション内を指すのは **18,600件**、範囲外は **6,930件**。元DBは保存し、別DB `XServiceLibraries_validated.sqlite` に実行領域内のレコードだけを残した。検証用プログラム: `ResearchTools/validate_imp_index.py`。このフィルタは誤ったメタデータアドレスを除外するが、対応するオーナークラスや呼び出し経路の真偽は判定しない。元インデクサ全体の修正完了を意味しない。


### OX-009 — Relative method IMPの生成時検証（2026-10-19）
**元インデクサのソースと実物Mach-Oで確認**: `scan_relative_method_lists` はObjective-C候補リストを探索し `imp_field_va+imp_rel` でアドレスを算出していたが、実行可能セクションに入るかを検証していなかった。修正版では `S_ATTR_PURE_INSTRUCTIONS` / `S_ATTR_SOME_INSTRUCTIONS` を持つセクションの範囲にあり、4バイト境界に整列するIMPのみ受理する。実物 `XServiceLibraries` で再スキャンした結果18,600件。以前の検証済みDBの18,600件と `(selector,imp)` が全件一致（差集合0件）。修正の再現用: `ResearchTools/repair_macho_indexer.py`。**留保**: クラス所有者・呼び出し関係・偽陽性の完全排除は未確認。元のツールは保存する。

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

## 2026-10-19 継続調査 — OX-011〜014

**実IPA再検証**: [詳細と再現手順](OfficialXTextSizingDisassembly.md)、[生証拠](OfficialXTextSizingEvidence.txt)。
- **OX-011**: 未解決6アドレスのC API / Objective-Cセレクタを解決。CTFrameGetLines、CTLineGetTypographicBounds、fast enumeration、および末尾文字列/単行/複数行の3分岐。
- **OX-012**: fitToSize:→_TFN_CTFrameGetSizeWithMaxLinesの直接BLを再確認。全CTFrame行の最大幅、制限対象行のorigin・ascent・descent、高さへの固定3.0加算、float32を経由する高さ切り上げを実命令から復元。maxLines非0のときだけ末尾改行を除外する経路。入力CTFrameの生成条件は別途解析が必要。
- **OX-013**: _tfn_buildTextPropertiesは末尾文字列length/lineBreakMode値1,2,4/maxLines==1で分岐。Single/Multi→更新関数→CTFrame生成への接続を確認。
- **OX-014**: TFNSizeThatFitsHelperはsubviewsのframe.maxYを採否判定付きで集計し、_TFNCeilToPixelの後でbottomContentPaddingを加算。CTLine直接計測とは別処理。
- **訂正**: 旧extract_class_methods.pyは間接selector参照を文字列として誤受理する場合があった。今回の観測headerに限定して参照を直接解決するよう修正し、37+7メソッドを再実行・実行領域照合した。OX-010の主要selector/IMP対応は再確認できた。
- **T1候補の追加事実**: 0x408300でxds_content_body、font/boldFont/lineHeight設定、attributedTextModelForOptions:送信を確認。所有クラス・TFNへの到達・本文使用条件は未確定。
- **留保**: 公式X実機の高さを測定した結果ではない。固定3.0をScarlet Xの本文へ適用する根拠はまだない。アプリコード・バージョンは変更していない。

## 2026-10-19 継続調査 — OX-015〜018

詳細・生証拠は既存のOfficialXTextSizingDisassembly.md / OfficialXTextSizingEvidence.txtへ追記。
- **OX-015（実命令）**: CTFrame生成0xC9FE48..0xCA00CCはCGPointZero+入力幅/高さのpathで初回frameを作り、行数>maxLinesのとき計測高さhからCGRect(0,0,W,H−h)を作り、Core Textのclipping paths属性でframeを再生成する。成功/失敗とtruncated flagも区別。
- **OX-016（訂正）**: OX-001の0x408300はT1StatusWithheldInCountryViewの**クラスメソッド**。メタクラス0x1AF3E20→ro0x19B5C58→method list0x1393468→entry0x1393488で確認。通常本文の経路として扱う根拠はなかった。元記録は保持し所有者を補足。
- **OX-017（静的接続）**: XAppLibrariesでTFNTwitterStatusのattributedTextModelForOptions:（0x98C588）→display-model選択。新規生成のclassref rebaseはTFNTwitterDisplayTextModel（0x6578C48）。同クラスのattributedTextModelForOptions:（0x96EE74）はTFNAttributedTextModelへのbind（slot0x6540EB8、ordinal12444）をallocし、initWithAttributedString:colorProviderView:へ渡す経路を持つ。
- **OX-018（実命令）**: TFNTwitterStatus高さ取得0x98C518→display-model高さ取得0x96E3C4。再計測側にfitToWidth:→actualSize→float32正方向切り上げ→signed integer返値を確認。キャッシュ経路もある。メソッド型q24@0:8@16で、CGFloat戻り値と混同しない。
- **未確認**: 実際の本文view/cellからの呼び出し、通常options/font/width、生成属性の全内容、セル高さの合成、実機一致。アプリ本体は変更しない。

## 2026-10-19 継続調査 — OX-019〜021

既存OfficialXTextSizingDisassembly.md / OfficialXTextSizingEvidence.txtへ根拠を追記。
- **OX-019**: TTAStatusBodyTextView高さAPI0x2CCC9EC→displayType 0/3/4/5/6ではviewModel.attributedTextModelHeightForOptions:→pixel丸め。1/2ではSelectableTextViewのsizeForAttributedTextModel:width:textKit2Enabled:へ。実renderer生成も同条件でAttributed/Selectableに分岐。本文viewからモデル計測への静的接続を確認したが、通常タイムラインの実行時typeとセル全体の合成は未確定。
- **OX-020**: fontOptions補助0x2CCC518を解析。type0 content_body/Bold・layoutMetrics.lineHeight・lineSpacing0、type1/4 headline2(+3)・Chirpによって0/2、type2 body(+3)・0/2・emptyLineMaxHeight=floor(lineHeight/3)、type3 custom30、type5両方content_bodyBold、type6 subtext2。bit33 overrideあり。トークン実ptとDynamic Type実条件は未確定。
- **OX-021**: 属性生成0x972D38→NSMutableAttributedString(TFSFillTemplates)カテゴリinitializer→_setFont:→CTParagraphStyleCreate。最小行高、同じ入力の最大/最小行間、調整0、段落間隔、alignment/linebreak/directionを設定。NSParagraphStyle.lineSpacingと同一視しない。lineHeight<=0時のfallbackはfont.lineHeight+3。最大行高はこの設定群にない。
- **表示更新**: 有効幅はselection paddingが有効ならmax(bounds.width−2P,0)。model生成→setTextModel:、dirty/layout metrics判定、invalidateIntrinsicContentSize、layoutSubviews→setFrame:も確認。
- 新規ツール: direct B/BL selector-stub呼出し探索、カテゴリowner解決。元IPA/SQLiteとアプリ本体は変更していない。


## 2026-10-19 継続調査 — OX-022

- **OX-022（XAppLibraries実命令）**: OX-019で特定したSwift側包含関数 `0x30C31C0..0x30C37F0` の `0x30C35A0` 本文高さAPI callerを追加追跡。返り高さが正なら対象ビューをその高さで `setFrame:` して `setHidden:NO`、0以下ならゼロ矩形・`setHidden:YES`。正の場合は後続座標計算で8.0等を加える経路があるが、**Core Textの文字計測への8pt追加ではない**。別viewの `sizeThatFits:` も後続に存在。所有Swift型、runtime displayType、通常タイムラインでの採用、最終セル高さへの接続は依然未確定。
- 詳細と命令bytes: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-022。対象Mach-O SHA-256は引き継ぎ値と再照合済み。Capstone未導入の実行環境でLLVM objdumpを使用。静的解析であり公式Xの実機計測ではない。
- アプリ本体・バージョン・mainを変更していない。
