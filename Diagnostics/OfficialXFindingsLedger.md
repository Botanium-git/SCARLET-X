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

## 2026-10-19 継続調査 — OX-023

- **OX-023（実バイナリ・直接分岐探索）**: XAppLibrariesの`__TEXT,__text`内のAArch64直接`BL`を復号し、OX-022の関数`0x30C31C0`へ直接呼ぶ`0x30C3B24`を確認。直接`B`は0件。前者の命令語`0x97FFFDA7`、file-order bytes `A7 FD FF 97`。llvm-objdumpでも直接照合。
- `0x30C3B10`開始の小関数がこのBLを持ち、前後に`0x4A44560`呼び出しと`0x4A44554`へのtail branchを持つ。**所有Swift型・closure用途・通常タイムライン採用は未解決**。間接呼び出し・Swift vtable/witness・ObjC dispatchや別Mach-Oを走査結果の0件と混同しない。
- 詳細と再現方法は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md)のOX-023。公式X実機計測ではなく、アプリ本体の変更なし。

## 2026-10-19 継続調査 — OX-024

- **OX-024（実バイナリ・所有者確定）**: OX-023の小関数`0x30C3B10`は、XAppLibrariesの`-[XActivityHistory.VideoRowView layoutSubviews]`（Objective-C登録名 `_TtC16XActivityHistory12VideoRowView`）のIMP。`__objc_methlist` list `0x4B0F840`（4 entries）→entry `0x4B0F860`→IMP field `0x4B0F868`→0x30C3B10、selector `layoutSubviews`、type `v16@0:8`。`__objc_data` class_ro相当 `0x65D6220`のbaseMethods pointer `0x65D6240`→上記method list、name pointer `0x65D6238`→`__objc_classname` 0x593FC70でownerを照合。内部`0x30C3B24`は`0x30C31C0`へ直接BL。
- **優先順位の訂正**: 前回の「Swift所有者未確定」はこの直接呼び出しについて解消。ただし**Activity HistoryのVideoRowViewであり通常タイムラインの証明にはならない**。`0x30C31C0`の全ての間接callerや実行時displayTypeは引き続き未確定。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-024。
- 公式Xのruntime観測ではない。アプリ本体・main・バージョン変更なし。

## 2026-10-19 継続調査 — OX-025

- **OX-025（T1Twitter実クラスの候補整理）**: 元T1Twitterのclass定義とro/baseMethodsを照合。`T1StatusCell` class `0x1AEF370`→method list `0x13D37C0`（61件）、`T1StatusCellLayout` `0x1AEF348`→`0x13D3AA8`（5件）、`T1StandardStatusViewLayoutStateGenerator` `0x1AED818`→`0x13D2F00`、`T1StandardStatusViewLayoutState` `0x1AED8B8`→`0x13D2E50`。`T1StatusCell layoutSubviews` 0x2F0B74、`sizeThatFits:` 0x2F0BE4、generator `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` 0x2AE63Cを索引・Mach-Oと照合。
- **留保**: 名前から通常タイムラインでの実行を断定しない。XAppLibrariesのTTAStatusBodyTextView計測へ接続された証拠、runtime displayType/幅/フォント、最終セル高さは未確認。OX-024のVideoRowViewとは独立した次の探索入口として保存。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-025。

## 2026-10-19 継続調査 — OX-026

- **OX-026（T1Twitter実命令とObjC stub/selref解決）**: `T1StandardStatusViewLayoutStateGenerator` の `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` 0x2AE63C について、入口の引数退避、キャッシュ選択分岐、および実ObjC stubとselector文字列を照合。解決した主なselectorは `initWithStatusViewModel:options:account:scribeContext:` (0x1303880)、`isStatusViewLayoutStateGeneratorCachedViewAdapterSetEnabled` (0x13104E0)、`customizeLayoutMetrics:forViewModel:viewAdapterSet:` (0x12E87A0)、`viewIdentifiersWithValidLayoutStateInSet:forViewModel:layoutMetrics:` (0x1370B80)、`populateLayoutStateSet:withValidViewIdentifiers:inPreviousLayoutState:` (0x1323D80)。`promotedBadgePlacement`の戻り値を1/2と比較する命令を確認したが**TTAStatusBodyTextViewのdisplayType分岐とは無関係な数値として区別**。
- **留保**: 間接dispatch先の所有クラス、通常タイムラインでのruntime採用、本文高さAPI・最終セル高さへの接続は未確定。詳細のslot/命令/解釈は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-026を参照。アプリ本体・バージョンは変更していない。

## 2026-10-19 継続調査 — OX-027

- **OX-027（T1Twitter実命令）**: T1StandardStatusViewLayoutStateGenerator の `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` 内 `0x2AED94..0x2AEE30` を追加逆アセンブル。`0x2AEDE0` の呼び出し結果 d0 を d8 へ加算し、`0x2AEE00` の結果 d1 を減算し、`0x2AEE20 fmaxnm d8,d11,d14` で値を選ぶ経路を確認。直後はx0と7の比較による分岐。
- **留保**: 本文高さ、画像/カードの寸法、または別の配置座標かは未確定。`0x12A99AC`, `0x12F3B40`, `0x131EC80` 等のstub/receiver/型を解決するまで、セル高さ式の発見と扱わない。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-027。
- 元T1Twitter SHA-256再照合済み。実機未確認。アプリ本体・main・バージョン変更なし。

## 2026-10-19 継続調査 — OX-028

- **OX-028（T1Twitter実Mach-Oのstub/bind照合）**: OX-027の未解決演算を再調査。`0x2AED94 -> 0x12A9694`は`_TFNBaselineEdgeInsetsForNonTextWithSimulatedFont`へのchained bind（GOT `0x1868000`）、`0x2AEDE0 -> 0x12A99AC`は`_TFNVerticalSpacingForBaselineEdgeInsets`へのbind（GOT `0x18682C0`）。`0x2AEDB0`/`0x2AEDF0`のreceiverに対するselectorは`objectAtIndexedSubscript:`（引数index=5）、`0x2AEE00`はその返却オブジェクトに対する`frame`。後続の`fsub d11,d8,d1`ではframeの第2double成分を引く。
- **区別**: この演算をCore Text本文高さの直接合成とは扱わない。非テキスト用baseline間隔とview frame位置の計算が関与している。index 5は本文displayType 5ではない。collectionの型、選ばれたview、d8/d14由来、補助関数内部式、最終セルサイズは未確定。旧OX-027は保存し解決情報を追記。
- 生証拠のslot/命令・再現コマンドは[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-028。公式X実機観測なし、アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-029

- **OX-029（T1Twitter Mach-O class owner解析）**: `T1StandardStatusBodyViewAdapter`のnlist class `0x1AF28B8`→ro `0x19AD578`→relative instance method list `0x13D15F0`（header `0x8000000C`、36件）を元Mach-Oで確認。特に`initializeView` 0x3BA7C0、`setViewModel:forView:` 0x3BA890、`layoutStateForViewModel:layoutMetrics:` 0x3BAE90、`_t1_displayTextOptionsForViewModel:` 0x3BB778、`displayType` 0x3BBED4、`displayLocation` 0x3BBEE4をowner付きで抽出。本文のタップ・省略表示トークンdelegateも持つ。
- **実命令**: layoutStateForViewModel:layoutMetrics:の非nil経路に`0x3BAF28 ldr x8,[x0,#0x10]`→`0x3BAF34 blr x8`の間接関数呼び出し、返されたv0/v1の保存、`0x3BAF50 fcmp d8,#0`を確認。これは単純な直接selector呼び出しではない。対象callbackの所有元/値の意味を解明するまで本文高さAPIや最終セル高との同一性を断定しない。
- **留保**: 通常タイムラインでのruntime使用、TTAStatusBodyTextViewへの接続、displayTypeとフォント実値は未確認。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-029。アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-030

- **OX-030（実バイナリ接続）**: T1Twitterの`T1StandardStatusBodyViewAdapter initializeView`（0x3BA7C0）が読むclassref slot `0x1AD5FC8`はXAppLibrariesの`_OBJC_CLASS_$_TTAStatusBodyTextView`にchained bind。`0x12FF2A0`は`initWithDisplayType:`（selref `0x1AA7E70`）。**本文adapter→本文ビューの生成を静的確認**。
- **間接計測関数の意味**: `layoutStateForViewModel:layoutMetrics:`（0x3BAE90）の`0x1319BA0`は`maximumSizeBlock`（selref `0x1AAE8B0`）。非nil時には`0x3BAF28`でblock invoke pointerを読み、`0x3BAF34 blr x8`でviewModel・layoutMetricsを渡す。返りv0/v1を保持し、第一成分が0なら`bodyWidth`（stub `0x12DB600`、selref `0x1A9EF48`）から幅を採る。
- `0x12BB1C0`は`_t1_convertToAutoTranslatedViewModelIfNeeded:`（selref `0x1A96E38`）。`0x3BB074`付近に条件付き-8.0があるが**本文高さへの一律減算ではない**。
- **依然未解決**: maximumSizeBlockの設定元/実装、通常タイムラインでのadapter採用条件・displayTypeの実値、TTA高さAPIへの具体的引数伝播、最終セル合成。詳細の命令と出典は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-030。公式X実機未測定、アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-031

- **OX-031（T1Twitter実命令）**: `T1StandardStatusBodyViewAdapter layoutStateForViewModel:layoutMetrics:` 0x3BAE90の後半を再解析。`maximumSizeBlock`がnilなら`layoutMetrics.bodyWidth`と高さ0を候補とし、blockがあれば結果のv0/v1を幅/高さ候補として保持。幅が0ならbodyWidth、条件付き幅-8pt分岐も存在。
- **サイズ合成**: `0x3BB270..0x3BB2AC`で幅d8・高さd9が両方正のとき、`W=d8+2*d10`, `H=d9+d11+2*d10`を形成して後続callへ渡す。どちらかが0以下なら別のメモリ定数からサイズを設定する分岐。**d10/d11をpaddingと確定したわけではない**。同じ関数の後続にTTAStatusBodyTextView classrefを使用する箇所もあるが、具体的selector・最終size・通常タイムライン採用は未確認。
- 根拠の命令語・PCと未解決範囲は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-031。アプリ本体・main・バージョン未変更、公式X実機未確認。

## 2026-10-19 継続調査 — OX-032

- **OX-032：本文height APIへの直接接続を解決**。T1Twitter `T1StandardStatusBodyViewAdapter layoutStateForViewModel:layoutMetrics:` 0x3BB158 のobjc stub `0x12F8400`は、`TTAStatusBodyTextView heightForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:richTextEnabled:trailingString:maxLines:attachmentDelegate:textKit2Enabled:cachingEnabled:` selector。続いて返るheightとmaximumSizeBlock側の高さ候補d9を `d9>0 ? fminnm(d9, heightAPIResult) : heightAPIResult` で統合する。
- **d10/d11の意味**: optionsのbit33がoffなら、TTAStatusBodyTextViewのクラスメソッド `selectionPadding` → d10、`linkTapDetectionBottomPadding` → d11。bit33がonなら両者0。正のサイズ候補では `W=d8+2*d10`、`H=d9+d11+2*d10` をレイアウト状態へ `setSize:`、その後 `setAdditionalEdgeInsets:` で負の差分を記録。非正の別サイズ分岐も確認。
- `displayType`は1/2比較に使用。後段はTTAStatusBodyTextViewの`fontForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:`も呼ぶ。**ただし通常タイムライン採用条件・実際のdisplayType、bit33の機能名、padのpt数、maximumSizeBlock設定元はまだ未確認**。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-032。アプリ本体/main/バージョン未変更。

## 2026-10-19 継続調査 — OX-033

- **OX-033**: XAppLibraries `TTAStatusBodyTextView.linkTapDetectionBottomPadding` IMP `0x2CCCBDC` は `fmov d0,#6.0; ret` で定数 **6pt** を返す。`selectionPadding` IMP `0x2CCCBD0` はclassref `0x6540D98`の `_OBJC_CLASS_$_TFNAttributedTextView` へ、selector `selectionPadding` (selref `0x651E550`) を転送。したがって selectionPadding の実数値は **XServiceLibraries の呼び先を解析するまで未確定**。
- この6ptはOX-032の **bit33 offかつ本文サイズ正** の合成式における `linkTapDetectionBottomPadding` の値であって、すべてのセルに無条件に加算してよいという根拠ではない。`maximumSizeBlock` 設定元、通常タイムラインでのbit33/displayTypeは未解決。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-033。アプリ本体/main/バージョン未変更。

## 2026-10-19 継続調査 — OX-034

- **OX-034**: XServiceLibraries SHA-256 `09e830331f35a7806f477cd0cbd497642461c44face5f818d39f9abd0b3040fc` の `_OBJC_METACLASS_$_TFNAttributedTextView` `0x44226A8` → ro `0x41C2D20` → relative methods `0x2F83590` 内、selector `selectionPadding` entry `0x2F83598` → IMP `0xCB52A8` を実Mach-O照合。`fmov d0,#2.0;ret` により **selectionPadding=2pt** を確定。OX-033の **linkTapDetectionBottomPadding=6pt** と合わせ、OX-032のbit33 off/正の本文サイズ経路ではレイアウトstateへ `W=幅候補+4pt`, `H=採用本文高+10pt`。さらにnegative `additionalEdgeInsets`も設定するため表示上の最終余白と同一ではない。bit33 onの場合padding両方0。通常タイムラインの実bit33・displayType、maximumSizeBlockの設定元は引き続き未確定。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-034。アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-035

- **OX-035：maximumSizeBlockの実所有クラス確認**。T1Twitter `T1StandardStatusBodyViewAdapter` (class `0x1AF28B8`) のsuperclass slot `0x1AF28C0` は、XServiceLibraries `_OBJC_CLASS_$_TFNComposableViewAdapter` へのchained bind。本文adapter own method list（36件）にmaximumSizeBlock/accessorは存在せず、superclass `TFNComposableViewAdapter` のrelative method list `0x2FB4810`（28件）に `maximumSizeBlock` IMP `0xCD8038` と `setMaximumSizeBlock:` IMP `0xCD8040`を確認。getterは `[self+0x30]` を返し、setterはoffset `0x30`で共通保存処理へ分岐する。
- これによりOX-030のblock invokeの所有元/ivarの一部を解決。ただし**実際のsetter呼出し元・具体的block invokeアドレス・通常タイムラインの設定条件は未解決**。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-035。アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-036

- **OX-036**: `T1Twitter` 内 `setMaximumSizeBlock:` selref `0x1AB9300` → objc stub `0x13444E0`を元Mach-Oで照合し、`__text`からこのstubへの**直接BLを35箇所**確認。件数は設定対象の数ではなくcallsite数。
- `T1StandardStatusViewLayoutStateGenerator._t1_viewAdapterSet`（0x2A7410）内`0x2A7648`のreceiverは `T1StandardStatusAttachmentViewAdapter`（classref `0x1AD48B8`→class `0x1AEFB18`）。定数block `0x187BB08` のinvoke `0x2A8560` は `layoutMetrics.bodyWidth` と高さ0を返す。**本文adapterの最大高さ制限とは別**。
- 別callsite `0x329B88`のstack block invoke `0x329E70`は `bodyWidth` + captured doubleを幅、高さ0を返すことを確認。ほかのcallsiteも精査が必要。
- **本文adapterへのsetter呼び出しと本文用block実装はまだ特定できていない**。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-036。公式X実機未確認、アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-037

- **OX-037**: classref `0x1AD48A8`→`T1StandardStatusBodyViewAdapter` class `0x1AF28B8`をdyld-infoで解決し、本文adapter自身をreceiverとする`setMaximumSizeBlock:`呼出しを **2経路**で確認。`_t1_viewAdapterSetWithLayoutMetrics:` (IMP `0x2080F4`) は生成した本文adapter `[sp,#0x98]`に`0x208540`でglobal block `0x1879160`（invoke `0x2088AC`, height=0）を設定。`_t1_viewAdapterSetWithMaxWidth:` (IMP `0x2C4FEC`) は生成した本文adapter `[sp,#0x58]`に`0x2C5214`でstack/copy block（invoke `0x2C53D4`, height=0）を設定。
- **OX-036精密化**: 0x208530..0x208650 の19 setter callsiteのうち、同一block `0x1879160`なのは `0x208530..0x208620`の**16件**。0x208630は`0x18791C0`、0x208640と0x208650は`0x1879180`。以前の「19件が同一block」は不正確だったため訂正。
- OX-032のheight cap条件 `maximumSizeBlock.height>0` と合わせ、**この2経路は高さ上限をblockから指定しない**と判断できる。ただし他の経路、通常タイムラインでの実際の採用条件、実機観測は未確認。解析詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-037。アプリ本体/main/バージョン変更なし。

## 2026-10-19 継続調査 — OX-038

- **OX-038（前回2経路のowner確定）**: 元T1Twitter Mach-Oの**メタクラス→relative method list→selector selref→IMP**を直接照合。OX-037経路A `0x2080F4` は `+[T1QuotedStandardStatusView _t1_viewAdapterSetWithLayoutMetrics:]`（meta `0x1AEAF78`、method list `0x1392710`、selref `0x1A9BC30`）。経路B `0x2C4FEC` は `+[T1DirectMessageConversationStatusView _t1_viewAdapterSetWithMaxWidth:]`（meta `0x1AEDE58`、method list `0x13917C8`、selref `0x1A9BC38`）。前回確認済みのbody adapterへのmaximumSizeBlock設定は**引用投稿ビュー/DM投稿ビューの生成処理内部**である。
- **解釈上の訂正**: これら2経路の高さ0 blockを通常のホームタイムライン本文に適用してよい根拠はない。引用投稿はホーム上でも表示され得るため「ホームで使用されない」との断定もしない。通常の標準投稿におけるblock設定有無、全呼出し元、runtime表示条件は未確認。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-038。アプリ本体/main/バージョン変更なし、実機観測なし。

## 2026-10-19 — OX-039

- T1Twitter `T1StandardStatusViewLayoutStateGenerator._t1_viewAdapterSet` (0x2A7410) creates `T1StandardStatusBodyViewAdapter` through classref `0x1AD48A8` (rebase to `0x1AF28B8`) around 0x2A75C4..0x2A75DC. Initializer receives w2=14, x3=0, x4=0; exact selector and semantic meaning unresolved.
- The **only directly observed** `setMaximumSizeBlock:` BL in disassembly range 0x2A7410..0x2A8560 is `0x2A7648`, with **`T1StandardStatusAttachmentViewAdapter`** (classref `0x1AD48B8`) as receiver and block `0x187BB08` as argument. Thus the already-confirmed height=0 block here applies to attachment, not directly to body. This does not prove the body adapter's block is nil or absent in runtime. See [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-039. No app/main/version changes.

## 2026-10-19 — OX-040

- T1Twitter objc stub `0x13055A0` resolves via selref `0x1AA9730` to **`initWithViewIdentifier:displayType:displayLocation:`**. In `T1StandardStatusViewLayoutStateGenerator._t1_viewAdapterSet`, the `T1StandardStatusBodyViewAdapter` created at `0x2A75C4..0x2A75DC` receives **viewIdentifier=14, displayType=0, displayLocation=0**. This corrects OX-039's unresolved interpretation of numeric argument 14: **14 is not displayType**. These values are static evidence for this generator, not yet proof of real home timeline execution. Direct `setMaximumSizeBlock:` in this region remains attachment-only. Full instructions: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-040. No app/main/version changes.

## 2026-10-19 — OX-041

- Static call-edge check: the indexed method `T1StandardStatusViewLayoutStateGenerator layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` has IMP `0x2AE63C`. An ARM64 signed-BL decoding scan across T1Twitter's executable `__TEXT,__text` VM `0x4000..0x129A124` returned **zero direct BLs** to either `0x2AE63C` or `_t1_viewAdapterSet` `0x2A7410`. This result covers **direct BL only**, not objc_msgSend selector dispatch, blocks, function pointers, and it **does not establish that the generator is unused**. Home-timeline dispatch and actual displayType are still unverified; OX-040's displayType=0 applies to construction in this generator only. Detail: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-041. No app/main/version change.

## 2026-10-19 — OX-042

- T1Twitter ObjC selector `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` has stub `0x1314C80`, selector ref `0x1AAD4E8`; ARM64 `BL` scan found **7 direct calls to the selector stub**, at `0x25F400`, `0x25FEC0`, `0x2A8B30`, `0x2EF85C`, `0x32A678`, `0x32A90C`, `0x8498F0`. This does not contradict OX-041's zero direct calls to the generator IMP `0x2AE63C` because these are dynamic ObjC method dispatches. The receiver class at each site remains unverified, so normal home timeline use of `T1StandardStatusViewLayoutStateGenerator` is still **not established**. See [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-042. No app/main/version change.

## 2026-10-19 — OX-043

- T1Twitter callsite `0x2A8B30` (OX-042) receiver x22 is derived from the `layoutStateGenerator` getter: objc stub `0x1314CC0`, selref `0x1AAD4F8` → method name `layoutStateGenerator`. Result retained into x22 at `0x2A8ABC`; `0x2A8B18` copies x22 to x0 before `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` selector send. This confirms **getter-result dispatch**, not the concrete runtime generator class. Containing owner, property assignment and home-timeline dispatch remain unverified. Full evidence: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-043. No app/main/version change.

## 2026-10-19 — OX-044

- **OX-044（標準ビューから標準レイアウト生成器への静的接続を確立）**: OX-042のselector call `0x2A8B30`を含む所有者は `-[T1StandardStatusView _t1_updateLayoutStateWithLayoutMetrics:]` IMP `0x2A8A80`（元Mach-O class relative methods確認）。このメソッドで `layoutStateGenerator` getterの結果をx22に保持し、レイアウト生成selectorのreceiverにする。
- `+[T1StandardStatusView layoutStateGenerator]` IMP `0x2A73A0`（メタクラスmethod list `0x1392F00`）はキャッシュ対象を返し、初期化側 `0x2A73E4..0x2A7400`が classref `0x1AD53C8`→`T1StandardStatusViewLayoutStateGenerator` class `0x1AED818`を使用して生成器を保存する。よって標準投稿ビュー→標準レイアウト生成器→body adapter（OX-040、displayType=0）の**静的接続**が裏付けられた。
- **制限**: 実ホームタイムラインでこのビューがいつ/必ず使われるか、表示の実測条件・フォントサイズは未確認。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-044。main/アプリ本体/バージョン変更なし。

## 2026-10-19 — OX-045

- `T1StandardStatusView` class symbol `0x1AED840` has a concrete rebased `__objc_classrefs` slot `0x1AD3E30` in T1Twitter. One resolved access (`0x2A86E8..0x2A86F0`) sends selector `layoutTracingSamplingFractionalPercentage` (objc stub `0x1314DA0`, selref `0x1AAD530`) to the class and then passes its return value to another method. This specific reference concerns tracing settings, **not verified status-view allocation or home timeline placement**.
- OX-044's internal standard-view→generator link remains intact, but normal home-timeline adoption is **unconfirmed**. Classref occurrence alone does not prove an on-screen use. Details: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-045. No app/main/version change.

## 2026-10-19 — OX-046

- `T1StatusCell` uses the same internal object (ivar-offset storage at VM `0x1ADD804`) for status rendering/layout: `setCellLayout:` IMP `0x2F09F4` sends `setLayoutState:` (`0x13431A0`); `layoutSubviews` IMP `0x2F0B74` sends `setFrame:` (`0x133F080`); `sizeThatFits:` IMP `0x2F0BE4` delegates to `intrinsicContentSize` (`0x1306D60`). Adjacent reset/update code sends `setViewModel:options:account:` (`0x1352060`). These selectors and ivar reads were checked against original T1Twitter Mach-O.
- This identifies a **cell → inner status-view layout/measurement bridge**, but **does not prove** that the inner runtime class is `T1StandardStatusView`, nor that this cell is selected by the ordinary home timeline. The constructor/ivar assignment and caller selection remain to investigate. Detailed addresses and limits: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-046. App code/main/version untouched.

## 2026-10-19 — OX-047

- `T1StatusCell` class relative-method list (`0x13D37C0`, 61 instance methods) identifies `initWithStyle:reuseIdentifier:` IMP `0x2EF97C` and `statusViewWithFrame:` IMP `0x2F099C`. The initializer calls `statusViewWithFrame:` (objc stub `0x135CC00`) and retains its return in the internal ivar via offset pointer `0x1ADD804`. This is the same object used for sizing and layout in OX-046.
- `statusViewWithFrame:` obtains **`statusViewClass`** through selector stub `0x135CB40`, allocates the returned class, then calls **`initWithFrame:isInCell:isDarkBackground:`** (stub `0x12FFE60`, immediate flags `isInCell=1`, `isDarkBackground=0`). Thus the cell instantiates an inner status-view **via class selection**, not an inlined hardcoded `T1StandardStatusView` classref. Actual implementation of `statusViewClass`, subclass overrides and which view is selected for ordinary home timeline remain unverified. Detailed evidence: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-047. No app/main/version changes.

## 2026-10-20 — OX-048

- 元T1Twitter Mach-Oのmetaclass relative method listで`statusViewClass`実装を2件確認。**`+[T1StatusCell statusViewClass]` IMP `0x2EF7B8`**（metaclass `0x1AEF398`, methods `0x1392FC0`）はclassref `0x1AD3E30`→**`T1StandardStatusView`**（class `0x1AED840`）を返す経路。**`+[T1ConversationFocalStatusViewTableViewCell statusViewClass]` IMP `0xC008`**（metaclass `0x1AE11F8`, methods `0x1391510`）はclassref `0x1AD1828`→**`T1ConversationFocalStatusView`**（class `0x1AED2F0`）を返す経路。
- OX-047のセルfactoryと組み合わせて、**標準T1StatusCellのクラス選択→T1StandardStatusView→standard layout generator→body adapter（displayType=0）→TTAStatusBodyTextView**の静的チェーンがつながった。ただし**通常ホームタイムラインでT1StatusCellが実際に登録・選択される条件は未証明**。会話注目投稿用には別の選択経路も存在。詳細は[OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-048。main/アプリ本体/バージョン変更なし、実機未確認。

## 2026-10-20 — OX-049

- `T1StatusCell` class VM `0x1AEF370`, classref `0x1AD1F08` confirmed in original T1Twitter dyld rebase. At `0x3F158..0x3F16C`, the classref is passed to selector **`tfs_safeCastAsClass:`** (stub `0x1366440`, selref `0x1AC1AD8`) for a checked cast of an existing object; the cast result then receives **`statusView`** (stub `0x135CB20`, selref `0x1ABF490`). **This is not a cell allocation or timeline registration**.
- A preliminary sqlite index search found three `statusCellClass` IMP candidates `0xE2FE44`, `0x295D70`, `0x41E0B8`, with class owner, implementation and home-timeline use **not yet proven**. This research does not establish that home timeline uses `T1StatusCell`. Detailed static evidence: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-049. App/main/version unchanged; no device runtime test.

## 2026-10-20 — OX-050

- Parsed all three `statusCellClass` class methods directly from T1Twitter metaclass-relative method lists. `T1StatusTableRowAdapter` IMP `0x41E0B8` returns `T1StatusCell` (classref `0x1AD1F08`); `T1ConversationFocalStatusTableRowAdapter` IMP `0x295D70` returns `T1ConversationFocalStatusViewTableViewCell` (classref `0x1AD5280`); `T1TweetSelectionTableRowAdapter` IMP `0xE2FE44` returns nil. This extends the static path `T1StatusTableRowAdapter` → `T1StatusCell` → `T1StandardStatusView` → standard generator → body adapter → TTA body view. **The home timeline's selection of T1StatusTableRowAdapter remains unverified**, so no runtime generalization is made. Full addresses: [OfficialXTextSizingDisassembly.md](OfficialXTextSizingDisassembly.md) OX-050. No app/main/version changes.


## OX-085 — v12.25 main executable: native home UI/stream factory class definitions (2026-10-22)

**Primary evidence:** User-provided unmodified official X v12.25 IPA, `Payload/Twitter.app/Twitter` (3,125,808-byte ARM64 main Mach-O). Extracted directly from IPA and checked using `llvm-objdump --macho --syms`, `--dyld-info` and byte reads.

- `_OBJC_CLASS_$_THFHomeTimelineItemsViewController` is a **defined** symbol at main-image VM `0x100276EE0`. Its corresponding `__objc_classlist` rebase at `0x10023F158` targets the same class. This is a concrete class definition in the main executable, unlike a mere undefined class reference.
- `_OBJC_CLASS_$_THFURTHomeTimelineStream` is defined at `0x1002793F0`, and `_OBJC_CLASS_$_THFURTHomeTimelineStreamFactory` at **`0x1002796B0`**. Class-list rebases at `0x10023F2D8` and `0x10023F2E8` target these classes respectively. This supplies a concrete *candidate class* for the home-stream factory returned in OX-082, **not proof of that method's return type**.
- The `THFHomeTimelineItemsViewController` class is also referenced by `__objc_classrefs` at `0x1002714F0`; `THFURTHomeTimelineStream` is referenced by `__objc_classrefs` at `0x100271338`. These references are not sufficient to establish the home-to-row-adapter selection chain.
- The exact selector text `urtHomeTimelineStreamFactoryWithApplicationLink:homeConfiguration:` exists at main executable file offset `0x204335` in `__objc_methname` (consistent with OX-084). Existence alone does not identify the implementation IMP or owner. Protocol declaration in T1Twitter remains a declaration (OX-084).

**Confirmed boundary:** The app's main Mach-O defines distinct native home items-controller and URT stream/factory classes that the earlier SQLite index (T1Twitter + XAppLibraries only) did not include. **Still unproven:** whether `THFURTHomeTimelineStreamFactory` is the concrete factory returned in OX-082, whether `THFHomeTimelineItemsViewController` is used in the user's home screen configuration, and the controller/stream → `T1StatusTableRowAdapter` runtime or static dispatch connection. No v12.35 device parity claims.

**Reproduce:**
```sh
unzip -p 'com.atebits.Tweetie2_12.25_und3fined(1).ipa' Payload/Twitter.app/Twitter > Twitter
llvm-objdump --macho --syms Twitter | grep -E '_OBJC_CLASS_\\$_(THFHomeTimelineItemsViewController|THFURTHomeTimelineStream|THFURTHomeTimelineStreamFactory)'
llvm-objdump --macho --dyld-info Twitter | grep -E '0x10023F158|0x10023F2D8|0x10023F2E8'
```

Research documentation only; no app or Probe changes.


## OX-086 — Decode concrete THFHomeTimelineItemsViewController method list and locate stream/adapter setup (2026-10-22)

**Primary evidence:** Unmodified user-provided official X v12.25 IPA main executable `Payload/Twitter.app/Twitter` (3,125,808 bytes). Direct 64-bit ARM64 Mach-O structure decoding and `llvm-objdump` disassembly; no inference from SQLite index.

- OX-085 class `THFHomeTimelineItemsViewController` at **`0x100276EE0`** has class data pointer to `class_ro_t` at **`0x100256AE8`**, whose *instance method list* is **`0x10019FE78`**. The relative method-list header is `0x8000000C`, count **161**; individual signed relative entries were decoded from original file and selector references resolved to original `__objc_methname` strings. These entries have executable IMP targets, unlike OX-084's protocol declarations.
- Relevant **verified instance selector → IMP** mappings:
  - `initWithAccount:timeline:` → **`0x1000B2ED8`** (index 1).
  - `viewDidLoad` → **`0x1000B5D7C`** (17).
  - `willDisplayCell:forItem:atIndexPath:` → **`0x1000BA0EC`** (69).
  - `didEndDisplayingCell:forItem:atIndexPath:inDataViewController:withPreviousDataViewAdapter:options:` → **`0x1000BA260`** (70).
  - `_streamDidUpdateWithNotification:` → **`0x1000BA724`** (76).
  - `_performIncrementalUpdate:animated:` → **`0x1000BA860`** (77).
  - `_statusOptionsForAdapter:args:options:` → **`0x1000BDA54`** (109).
  - `_statusViewModelAtIndexPath:` → **`0x1000BDBCC`** (110).
  - `_setupStreamFromTimeline` → **`0x1000BE908`** (115).
  - **`_registerAdaptersAndTransformersThatRequireStream:` → `0x1000BECFC`** (116).
  - `_representedItemsForStreamItem:` → **`0x1000BF150`** (120).
- The above confirms this *particular concrete controller* implements methods for stream setup, adapter/transformer registration, cell visibility and status-specific adapter/options processing. It gives a specific investigative entry point but does **not** yet identify which concrete adapter class is registered for an ordinary home status or its run-time use.
- Disassembled `_registerAdaptersAndTransformersThatRequireStream:` at `0x1000BECFC..0x1000BEEEC`: its incoming argument is saved in `x19` (`0x1000BED18`), an instance object is obtained through an ivar read from `self` (`0x1000BED28..0x1000BED30`), and the method makes several Objective-C sends and stores a resulting object into another ivar at `0x1000BEDC8..0x1000BEDD4`. Additional setup messages occur through `0x1000BEEA0`. The exact selectors/class receiver identities of these sends remain unresolved; **do not claim any specific T1StatusTableRowAdapter registration yet**.

**Next priority:** Resolve ObjC selector stubs used by `0x1000BECFC..0x1000BEEA0`, classrefs near `0x1002714B0..0x1002714C0`, and calls in `_setupStreamFromTimeline`. Then correlate any real adapter factory/setter with the already established `T1StatusTableRowAdapter → T1StatusCell` static chain (OX-050). Keep v12.25 static evidence separate from official X v12.35 device behavior.

**Reproduce:**
```sh
unzip -p 'com.atebits.Tweetie2_12.25_und3fined(1).ipa' Payload/Twitter.app/Twitter > Twitter
llvm-objdump --macho --syms Twitter | grep 'THFHomeTimelineItemsViewController'
llvm-objdump -d --start-address=0x1000becfc --stop-address=0x1000beef0 Twitter
```
Method-list decode: class data `0x100276EE0 + 0x20 → 0x100256AE8`; `class_ro_t + 0x20 → 0x10019FE78`; header `<II`, relative entries `<iii` with selector references through native rebase pointers.

Documentation only; no Scarlet X app, Probe, or main changes.


## OX-088 — Home status-options block invokes controller method (2026-10-22)

Original official X v12.25 IPA main Mach-O checked with llvm-objdump. In `-[THFHomeTimelineItemsViewController _registerAdaptersAndTransformersThatRequireStream:]` (0x1000BECFC), the block passed to `setStatusOptionsBlock:` is created with an invoke pointer at `0x1000BEF10`. Its `0x1000BEF58` BL targets ObjC stub `0x10017DF20`, which loads selector reference `0x100266790`; the Mach-O rebase resolves that pointer to string `_statusOptionsForAdapter:args:options:` at `0x1001DE6D5`. This confirms the block delegates status-option calculation to that controller method.

The method's previously established IMP `0x1000BDA54` was disassembled. It accepts incoming options in x4, processes conditional branches and ORs option bits into x20, and returns x20. The selection rules require decoding called selector stubs and conditions before attributing meaning to specific bits. In particular, neither actual runtime option values nor final body displayType is established here. This is v12.25 static evidence only; no application or Probe changes.


## OX-089 — Decode conditions and masks in home status options (2026-10-22)

**Primary evidence:** User-provided official X v12.25 IPA, original ARM64 main Mach-O `Payload/Twitter.app/Twitter`. Direct `llvm-objdump` disassembly of `-[THFHomeTimelineItemsViewController _statusOptionsForAdapter:args:options:]` at `0x1000BDA54..0x1000BDBC8`, selector-stub instruction decoding and chained dyld selref rebases.

The method copies incoming options `x4` into `x20` at `0x1000BDA6C`. It gets `item` (stub `0x100188120`; selref `0x100269010` resolves to `item`), then obtains a perspective/status through `statusForPerspectiveOrNil:` (stub `0x1001944E0`; selref `0x10026C100`). If `x23` status is nonnull (`0x1000BDB34..0x1000BDB38`), it branches on:

- `isSelfThreadStatus` at `0x1000BDB3C` (stub `0x100187EE0`, selref `0x100268F80` → `isSelfThreadStatus`). **False:** OR `0x81` into incoming options (`0x1000BDB68..0x1000BDB6C`).
- **True:** call `isReply` at `0x1000BDB48` (stub `0x100187E00`, selref `0x100268F48` → `isReply`). Both reply branches start from `0x20081` (mov 0x81, movk high 0x2). For nonzero `isReply`, the selected additional mask is `0x60081` (adds `0x40000`); for zero `isReply`, it is `0x20081`. Selected mask OR'ed with previous options at `0x1000BDB60`.
- Independently, `0x1000BDB88` calls selector `canShowCommunityAvatarForStatusViewModel:account:` (stub `0x1001804A0`, selref `0x1002670F0`) and conditional-selects `x20 | 0x8000000000` at `0x1000BDB8C..0x1000BDB94` when the call returns nonzero. This latter branch is within the nonnull-status region.
- **Null status:** `0x1000BDB34` branches to `0x1000BDBA0` without the above OR masks, returning the incoming options unchanged at `0x1000BDBB0`.

**Interpretation boundary:** These masks and branch conditions are directly evidenced for this function, but their individual semantic flag names, caller-supplied incoming options, runtime values and implications for `TTAStatusBodyTextView` displayType remain unverified. Do not equate the numeric masks with font size, paragraph spacing, or final cell height.

Reproduction: `llvm-objdump -d --start-address=0x1000bda54 --stop-address=0x1000bdbcc Twitter` and `llvm-objdump --macho --dyld-info Twitter` for selrefs `0x100269010`, `0x10026C100`, `0x100268F80`, `0x100268F48`, `0x1002670F0`. Read rebased NUL-terminated selector strings in original Mach-O.

Documentation only; no application, Probe, main branch, or version changes.


## OX-091 — Resolve receiver and argument handoff for status-option helper (2026-10-22)

**Directly checked:** user-provided original official X v12.25 IPA, `T1Twitter.framework/T1Twitter`; native ARM64 disassembly at `0x3AB20C..0x3AB31C`, with indexed class method-list cross-check.

Within `-[T1StatusTableRowAdapter dataViewController:tableViewCellForItem:withOptions:atIndexPath:]`:
- Entry saves `x2` data-view controller into `x19`, `x3` item into `x20`, `x4` options into `x21`, `x5` index path into `x22`, and `x0` (self) into `x24` at `0x3AB22C..0x3AB23C`.
- At `0x3AB2AC..0x3AB2BC`, message `statusAdapter` is sent to **self** (`x24`) via ObjC stub `0x135C640`. Its result is retained in `x26`.
- At `0x3AB2C0..0x3AB2D4`, the subsequent message `tableViewController:statusOptionsForViewModel:withOptions:atIndexPath:` (stub `0x1361540`) has **receiver x0 = statusAdapter result (x26)**. x2 receives `x19` data-view controller, x3 receives `x20` item/view-model argument, x4 receives original `x21` options, and x5 receives `x22` index path; the returned computed options in x0 are saved as x25.
- At `0x3AB30C..0x3AB31C`, `setViewModel:options:account:` is invoked on cell's inner `statusView`, with `x3=x25` computed option bits.

The supplied `scarlet_macho` SQLite lists `statusAdapter` getter at **IMP `0x3AB09C`** (decimal 3846044), and `setStatusAdapter:` at 0x3AC234 (decimal 3851868) in the same method list as the row adapter. It has **no indexed concrete ObjC implementation entry** for the exact selector `tableViewController:statusOptionsForViewModel:withOptions:atIndexPath:` among the two indexed images (T1Twitter, XAppLibraries). Absence from this partial index **does not prove no implementation in the full IPA**, category, protocol forwarding or dynamic dispatch.

**Meaning:** OX-090 helper method dispatch is to the *statusAdapter object*, not directly to `THFHomeTimelineItemsViewController`. The route from that object's helper to the OX-088/OX-089 home status-options block remains to be established by tracing `setStatusOptionsBlock:`, the statusAdapter class, and concrete helper implementation. Do not infer home runtime selection or bit meanings from this handoff.

Reproduce from original binaries:
```sh
llvm-objdump -d --start-address=0x3ab20c --stop-address=0x3ab340 T1Twitter
llvm-objdump -d --start-address=0x3ab09c --stop-address=0x3ab0d0 T1Twitter
```
No production code, Probe, main branch or version changes.


## OX-092 — Distinguish T1StatusTableRowAdapter statusAdapter and statusOptionsBlock accessors (2026-10-22)

**Evidence:** Original official X v12.25 `T1Twitter.framework/T1Twitter` binary, independently checked against user-supplied `scarlet_macho(1).sqlite` `objc_methods` index. Direct ARM64 disassembly using `llvm-objdump`.

For `T1StatusTableRowAdapter` method list `0x13A6278`, the index gives:
- `statusAdapter` getter **IMP `0x3AAF9C`**.
- `setStatusAdapter:` **IMP `0x3AC65C`**.
- `statusOptionsBlock` getter **IMP `0x3AC5A0`**.
- `setStatusOptionsBlock:` **IMP `0x3AC5B0`**.

At `0x3AC5A0`, the `statusOptionsBlock` getter loads an ivar-offset symbol via `adrp/ldrsw`, then reads the object at that offset. At `0x3AC5B0`, its setter loads that **same ivar offset** (page `0x1ADE000`, +`0x4EC`) and branches to the Objective-C property-storage helper at `0x12B0480`. It is not a method that itself calculates status options. The earlier `statusAdapter` getter pointer `0x3AB09C` stated in OX-091 was inaccurate: the actual indexed getter is `0x3AAF9C`; `0x3AB09C` falls in adjacent method code. This entry corrects that address without changing the verified OX-091 receiver handoff.

The index also lists `statusOptionsBlock` getter `0x144D4` and setter `0x144E4` in a **different** ObjC method list `0x13C9D98`, alongside `initWithAccount:statusOptionsBlock:customEventHandler:` at `0x12948`. These method records establish an additional holder with a similarly named block property, **not** the concrete class owner or how that object is connected to the row-adapter property.

**Next necessary check:** resolve the owner of method list `0x13C9D98` through native class_ro_t→class metadata and trace the concrete helper dispatch and block invocation. The getter/setter presence alone does not establish that the row adapter invokes its stored block or that the helper's receiver is the same object. This is static v12.25 evidence, not v12.35 runtime proof.

No application/Probe code or versions modified.


## OX-093 — Identify owner of alternate statusOptionsBlock method list (2026-10-22)

**Primary evidence:** Original user-provided X v12.25 `T1Twitter.framework/T1Twitter` Mach-O, native `llvm-objdump --macho --dyld-info`, `--syms`, instruction disassembly, and SQLite `objc_methods` list membership.

- Instance method list **`0x13C9D98`** is referenced by a rebased pointer at **`0x193A4A0`** in `__objc_const`. This is class-ro data at **`0x193A480 + 0x20`**.
- The ObjC class data pointer at **`0x1AE1628`** targets `0x193A480`. Thus the class starts at **`0x1AE1608`**. The Mach-O symbol table identifies it as **`_OBJC_CLASS_$_T1QuotedStatusItemTableRowAdapter`**, *not* `T1StatusTableRowAdapter`.
- Its list contains initializer **`initWithAccount:statusOptionsBlock:customEventHandler:` IMP `0x12948`**, `statusOptionsBlock` getter **`0x144D4`**, and setter **`0x144E4`**. Initializer disassembly at `0x12964..0x12A04` retains its arguments, copies the block argument through the same copy helper used for other block properties, and stores the copy through ivar offset at `0x1AD9FB8`. Getter/setter both load this same ivar offset.
- **Scope correction to OX-092:** The alternate `statusOptionsBlock` property is specifically owned by the *quoted-status item* row adapter. It is not evidence that the normal `T1StatusTableRowAdapter` dispatches to this quoted-status initializer or property. Analyze the two classes separately until an actual call edge shows interaction.

**Next:** Examine `T1StatusTableRowAdapter`'s own `statusAdapter` accessor and the owner/implementation of `tableViewController:statusOptionsForViewModel:withOptions:atIndexPath:`; separately trace the normal adapter's `setStatusOptionsBlock:` use. Do not conflate the quoted-status holder with ordinary home status-option forwarding.

Research/documentation only; no production application, Probe or version changes.


## OX-094 — Lazy statusAdapter creation and statusOptionsBlock installation (2026-10-22)

**Primary evidence:** Original user-supplied official X v12.25 IPA; directly extracted `T1Twitter.framework/T1Twitter`, disassembled with `llvm-objdump`. Cross-checked `objc_methods` in supplied SQLite (method list `0x13A6278`).

The verified `T1StatusTableRowAdapter` `statusAdapter` instance Getter (IMP **`0x3AAF9C`**) is **not a simple field load**:
- At `0x3AAFB0..0x3AAFBC`, it loads ivar offset via `0x1ADE4E8` and checks whether cached object x20 is nonzero; existing instance branches to `0x3AB080`.
- On a cache miss, `0x3AAFC4..0x3AAFF4` allocates via a classref at `0x1AD4848` (dyld rebase target `0x1AF4618`, symbol `_OBJC_CLASS_$_T1StatusTableRowAdapter`), loads another ivar from self at offset-symbol `0x1ADE4E0`, and sends ObjC stub `0x12FC100`. Its selref `0x1AA7208` resolves to **`initWithAccount:scribeImpressionCache:`** (literal at `0x161409A`).
- At `0x3AB000..0x3AB008`, the initialized result is stored in the cached-object ivar. At `0x3AB03C..0x3AB068`, a stack block is constructed and **`setStatusOptionsBlock:`** is sent to that newly cached object via stub `0x134DD60`, whose selref `0x1ABB920` resolves to the exact setter selector (literal `0x167DE53`).
- The method then returns the cached object through the retain/autorelease return sequence `0x3AB080..0x3AB09C`.

**Interpretation:** This is a concrete lazy construction and block-installation pathway for the object returned by the row adapter's `statusAdapter` Getter. It strengthens OX-091's finding that the subsequent helper selector is messaged to the Getter result. The classref rebase resolves to `T1StatusTableRowAdapter` itself in this inspected image; the precise runtime class and whether any subclass/bridging behavior affects dispatch should not be assumed from name alone. **Still unresolved:** stack-block invoke body `0x3AB0BC`, where and how that block invokes the owner row adapter's stored `statusOptionsBlock`, concrete implementation of `tableViewController:statusOptionsForViewModel:withOptions:atIndexPath:`, and values of individual option flags.

**Additional evidence check:** Getter `statusOptionsBlock` `0x3AC5A0` and setter `0x3AC5B0` read/write the same offset symbol `0x1ADE4EC`, separate from the cached `statusAdapter` slot `0x1ADE4E8`. This is why the two getters cannot be treated as aliases.

Reproduce with `llvm-objdump -d --start-address=0x3aaf9c --stop-address=0x3ab0a0 T1Twitter`, `llvm-objdump -d --start-address=0x12fc100 --stop-address=0x12fc114 T1Twitter`, `llvm-objdump -d --start-address=0x134dd60 --stop-address=0x134dd74 T1Twitter`, and `llvm-objdump --macho --dyld-info T1Twitter` for `0x1AA7208`, `0x1ABB920`, and `0x1AD4848`.

No production app, Probe, main branch or version changes.


## OX-095 — Status-options trampoline invokes stored block and post-processes flags (2026-10-22)

**Primary evidence:** Original user-supplied official X v12.25 `T1Twitter.framework/T1Twitter` extracted from IPA, disassembled directly using `llvm-objdump -d --start-address=0x3ab0bc --stop-address=0x3ab204`. Selector stub pointers cross-checked with `llvm-objdump --macho --dyld-info` and raw Mach-O strings.

The invoke function of the block constructed in `-[T1StatusTableRowAdapter statusAdapter]` (OX-094) is **`0x3AB0BC`**.

- Incoming x0 is the block, whose weak-captured object is read via `x0 + 0x20` at `0x3AB0F4..0x3AB100`; the retain-weak helper returns nil on failure, leading to cleanup and return.
- At `0x3AB104`, ObjC stub **`0x135CA80`** sends selector **`statusOptionsBlock`** (selref `0x1ABF468`) to the captured object. If the returned property/block is nonnull, **`0x3AB118..0x3AB12C`** reads its invoke pointer at offset `+0x10` and executes **`blr x8`**. Parameters passed are x1/x2/x3 received by the trampoline (saved in x19/x20/x21).
- The invoked block's return value is retained as the base options (`x21`, `0x3AB130`), before further post-processing.
- The later ObjC selector calls are **`item`** (stub `0x1313060`, selref `0x1AACDE0`), **`composition`** (stub `0x12E2FE0`, selref `0x1AA0DC0`), and **`isUndoable`** (stub `0x1311B60`, selref `0x1AAC8A0`). The resulting predicates and branches require care: the `item` object and its composition are involved, and an `isUndoable` decision changes whether bit `0x10` is kept.
- At `0x3AB18C`, `orr x26, x21, #0x800000` adds bit `0x800000`. At `0x3AB1B4..0x3AB1BC`, an `and` mask clears bit `0x10` in one branch, selected against the unmodified x26 according to an `isUndoable` result. The final value is returned in x0.

**Confirmed:** the normal row adapter's trampoline actively retrieves and executes the owner's stored `statusOptionsBlock`; this closes the gap from block installation (OX-094) to block execution. **Not yet confirmed:** implementation and runtime selection of the home-controller block that supplies those options, complete semantics of the flag masks, runtime values for official X 12.35, and propagation to particular `TTAStatusBodyTextView` displayType/font/layout choices.

Reproduce:
```sh
llvm-objdump -d --start-address=0x3ab0bc --stop-address=0x3ab204 T1Twitter
llvm-objdump -d --start-address=0x135ca80 --stop-address=0x135ca94 T1Twitter
llvm-objdump -d --start-address=0x1313060 --stop-address=0x1313074 T1Twitter
llvm-objdump -d --start-address=0x12e2fe0 --stop-address=0x12e2ff4 T1Twitter
llvm-objdump -d --start-address=0x1311b60 --stop-address=0x1311b74 T1Twitter
```
Documentation only; no Scarlet X or Probe code, version or main-branch changes.


## OX-096 — Verify option argument reaches status-cell layout generator (2026-10-22)

**Primary evidence:** Original user-provided X v12.25 IPA, freshly extracted `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`, directly inspected with `llvm-objdump -d`. Existing OX-090/095 describe upstream options path; this entry checks a specific downstream argument transfer without inferring final body displayType.

- `cellLayoutForViewModel:options:account:layoutMetrics:withPreviousLayout:` IMP **`0x2EF7C4`** is indexed in the supplied `scarlet_macho(1).sqlite` `objc_methods` for T1Twitter (list address recorded in index as decimal `20524992`); native disassembly confirms an actual code body at that address.
- At `0x2EF7E0..0x2EF7F4`, the method retains its incoming args: x2 model → **x24**, x3 options → **x22**, x4 account → **x23**, x5 layout metrics → **x19**, x6 previous layout → **x20**.
- At `0x2EF818..0x2EF82C`, it requests a class's `statusViewClass` (`0x135CB40`) and from that class obtains `layoutStateGenerator` (`0x1314CC0`), saving the generator result in **x25**.
- At **`0x2EF844..0x2EF85C`**, receiver x0=x25; x2=x24 model; **x3=x22 options**; x4=x23 account; x5=x19 metrics; x6=x26 previous-layout-derived result. The dispatch is selector stub **`0x1314C80`**, independently resolved earlier (OX-042) as `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:`. This confirms that the incoming options propagate to the layout state generator as an explicit argument.
- A separate layout-state-generator IMP at `0x2AE63C` begins by saving its incoming x3 options in **x21** (`0x2AE678`), then forwards x21 as x3 into an initializer call at **`0x2AE6CC..0x2AE6D4`**. This proves further argument use in that function, *not yet* the option-to-displayType mapping.

**Scope and caution:** The instructions establish an adapter/cell-layout → generator **parameter handoff**, not that the user-visible home cell always takes this branch, and not a complete proof that a particular upstream mask from OX-089/095 changes `TTAStatusBodyTextView` displayType or text height. The identity of the class returned by `statusViewClass` and the result of `layoutStateGenerator` at runtime remain subject to the class-selection conditions already noted in OX-047/048. Do not assume the numeric flags are text-format flags.

**Reproduce:** `llvm-objdump -d --start-address=0x2ef7c4 --stop-address=0x2ef8a4 T1Twitter`; `llvm-objdump -d --start-address=0x2ae63c --stop-address=0x2ae6e0 T1Twitter`. Code, Probe, version and main branch unchanged.


## OX-097 — Layout generator constructs combined status view model with forwarded options (2026-10-22)

**Primary evidence:** Original user-supplied X v12.25 IPA, `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`, directly inspected with `llvm-objdump`, raw Mach-O bytes, and SQLite `symbols` index; extends OX-096.

In the generator method with IMP **`0x2AE63C`** (indexed selector `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:`):

- At `0x2AE678`, incoming **x3 options** are retained in **x21**. The incoming model (x2) is retained in x23, account (x4) in x25, metrics (x5) in x19 and previous layout (x6) in x26.
- At `0x2AE6AC..0x2AE6C0`, classref **`0x1AD3868`** rebases to class **`0x1AE8868`**, identified by indexed class symbol as **`_OBJC_CLASS_$_T1StatusViewCombinedViewModel`**. It is passed to the allocator.
- At `0x2AE6C4..0x2AE6D4`, the allocated object receives ObjC selector **`initWithStatusViewModel:options:account:scribeContext:`**: stub `0x1303880` → selref `0x1AA8FE8` → native selector literal at `0x162099F`. The call passes **x2=x23 original status view model; x3=x21 original options; x4=x25 account; x5=0 nil scribe context**. Result is held in x22. Hence options definitely reach a concrete combined-view-model initializer in this code path, without modification at this handoff.
- At `0x2AE6DC..0x2AE6E4`, the generator sends **`isStatusViewLayoutStateGeneratorCachedViewAdapterSetEnabled`** (stub `0x13104E0`, selref `0x1AAC300`, literal `0x163094B`) to x25 (account). On nonzero return, it loads a cached object at `self+8`; otherwise it obtains a separately generated result by the alternate call at `0x2AE6F8..0x2AE70C`.

**Boundary:** This confirms a status-view combined-model construction and a cache-feature branch after options handoff. It does **not** yet decode the initializer's internal option-mask interpretation, establish which adapter set is actually used on v12.35, or imply that cache choice changes font size, body displayType or final row height.

**Reproduce:** `llvm-objdump -d --start-address=0x2ae63c --stop-address=0x2ae710 T1Twitter`; `llvm-objdump -d --start-address=0x1303880 --stop-address=0x1303894 T1Twitter`; `llvm-objdump -d --start-address=0x13104e0 --stop-address=0x13104f4 T1Twitter`; `llvm-objdump --macho --dyld-info T1Twitter` checking selrefs `0x1AA8FE8`, `0x1AAC300`, classref `0x1AD3868`.

No SCARLET-X production code, Probe, version or main branch changes.


## OX-098 — Resolve combined view model initializer owner and dispatch thunk (2026-10-22)

**Primary source:** User-supplied official X v12.25 IPA, extracted original `T1Twitter.framework/T1Twitter` (33,287,408 bytes). Parsed Mach-O `__objc_data`, `__objc_const`, `__objc_methlist` relative method records and chained selector pointers, independently checked against `llvm-objdump -d` and the existing SQLite index.

- Class `_OBJC_CLASS_$_T1StatusViewCombinedViewModel` is defined at VM **`0x1AE8868`**. Its `class_ro_t` is at **`0x196D0F8`**, whose method-list pointer at `0x196D118` rebases to **`0x13D6490`**.
- `0x13D6490` is a **14-entry relative instance method list** (header `0x8000000C`). The selector `initWithStatusViewModel:options:account:scribeContext:` is entry index **12**, its selector reference at **`0x1AA8FE8`** points to text `0x162099F`, and its signed-relative IMP resolves to **`0x199118`**. This is a direct native ownership resolution, *not* an inference from the earlier generator call.
- Native IMP disassembly at `0x199118..0x199154`: the method constructs a small stack context including self and an ivar-offset pointer loaded from `0x1AD8810`, loads another selector-ref from `0x1AA8FF0`, loads a constant pointer `0x18776A0`, then calls helper **`0x12B03CC`** at `0x199144`. It immediately returns after helper completion. There is **no directly visible options-bit mask/test in this short initializer thunk**.
- The earlier generator `0x2AE6D4` passes options as x3 into this initializer. The initializer then immediately invokes the helper, so **the actual processing of x3 and stored fields cannot be inferred from the short thunk alone**. Identify helper semantics (including whether super-init dispatch or forwarding), initializer superclass and any resulting ivar initialization before assigning specific meaning to options bits.
- **SQLite indexing caveat:** This exact initializer selector was missing from `objc_methods` search results despite being present in the native class method list. Incomplete index coverage must not be mistaken for lack of a concrete Objective-C method implementation.

**Reproduction:** Decode class object `0x1AE8868` data pointer `+0x20` to `0x196D0F8`, ro method pointer `+0x20` to `0x13D6490`, and entry 12's signed offsets; `llvm-objdump -d --start-address=0x199118 --stop-address=0x199154 T1Twitter`, `llvm-objdump -d --start-address=0x2ae6ac --stop-address=0x2ae6dc T1Twitter`.

No Scarlet X application or Probe modification; v12.35 runtime values and font/display-type relation remain unproven.


## OX-087 — Home controller registers standard status row adapter (2026-10-22, delayed record)

**Source:** Original user-provided X v12.25 IPA main `Twitter` Mach-O. In `-[THFHomeTimelineItemsViewController _registerAdaptersAndTransformersThatRequireStream:]` at `0x1000BECFC`, native classref `0x1002714B0` binds `T1Twitter::_OBJC_CLASS_$_T1StatusTableRowAdapter`; `0x1000BED90..0x1000BEDC4` allocates and initializes it with `initWithAccount:scribeImpressionCache:forAllInstancesInTableViewController:`. Around `0x1000BEDE8..0x1000BEDF0` the controller configures its `statusOptionsBlock`. At `0x1000BEE30..0x1000BEE38` the method calls `useDataViewAdapterForTweetPerspectives:` with that adapter. This is a concrete static home-controller registration path, **not proof that every post displayed at runtime uses it**. A distinct composition adapter is configured elsewhere in the same method. Originally investigated before OX-088; documentation was blocked at the time.

## OX-090 — Row adapter forwards computed options to cell and layout (2026-10-22, delayed record)

**Source:** Original X v12.25 `T1Twitter.framework/T1Twitter`. `T1StatusTableRowAdapter` implements `dataViewController:tableViewCellForItem:withOptions:atIndexPath:` at **`0x3AB20C`**, and `dataViewController:cellLayoutForItem:withOptions:previousLayout:atIndexPath:` at **`0x3AC078`**. Both call selector `tableViewController:statusOptionsForViewModel:withOptions:atIndexPath:` via stub `0x1361540`, with receiver obtained from `statusAdapter` (receiver distinction clarified in OX-091). Cell setup then sends `setViewModel:options:account:` around `0x3AB31C`; layout sends `cellLayoutForViewModel:options:account:layoutMetrics:withPreviousLayout:` around `0x3AC168`. Thus options are forwarded into both paths. **Does not establish particular flag meanings or v12.35 device behavior.** Originally investigated before OX-091; documentation was blocked at the time.

## OX-099 — Combined-model initializer delegates to imported superclass using objc_msgSendSuper2 (2026-10-22)

**Primary evidence:** Original X v12.25 `T1Twitter.framework/T1Twitter`, freshly extracted from user-supplied IPA. Native llvm-objdump disassembly at `0x199118..0x199150` and dyld rebases/binds checked directly.

- In `-[T1StatusViewCombinedViewModel initWithStatusViewModel:options:account:scribeContext:]`, at `0x199124..0x19912C` a super-class reference is loaded from `0x1AD8810`, which rebases to this subclass's class object `0x1AE8868`; this is the objc_super current-class argument, not the superclass identity.
- The selector reference `0x1AA8FF0` rebases to text `0x16209D6`: **`initWithStatusViewModel:options:account:scribeContext:cardAttachmentDecider:`** (additional argument).
- At `0x199138..0x199144` a constant pointer `0x18776A0` is passed in x6, and the call at `0x199144` goes to stub `0x12B03CC`. The stub loads GOT pointer **`0x186DAE8`**, whose dyld bind resolves to **`libobjc::_objc_msgSendSuper2`**. This proves Objective-C superclass dispatch rather than a local function doing option processing.
- The subclass's superclass pointer in its ObjC class data (`0x1AE8868 + 8 = 0x1AE8870`) binds **`XAppLibraries::_OBJC_CLASS_$_TTAStatusViewCombinedViewModel`**. Therefore the likely next implementation to inspect is the matching initializer on this imported superclass in XAppLibraries, while respecting category/override/dynamic dispatch conditions.
- This wrapper does not itself test option bits. Meaning, retention and subsequent use of options require inspection of the superclass initializer and downstream accessors; the literal `0x18776A0` has not yet been assigned semantics.

**Reproduce:** `llvm-objdump -d --start-address=0x199118 --stop-address=0x199154 T1Twitter`; `llvm-objdump -d --start-address=0x12b03cc --stop-address=0x12b03d8 T1Twitter`; `llvm-objdump --macho --dyld-info T1Twitter` for `0x186DAE8`, `0x1AA8FF0`, `0x1AD8810`, `0x1AE8870`.

No application, Probe, main branch or version changes.


## OX-100 — XAppLibraries combined-view-model superclass stores options at +0x50 (2026-10-22)

**Primary evidence:** Original user-supplied official X v12.25 IPA. Extracted `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries` (124,141,728-byte ARM64 Mach-O). Parsed native `__objc_data`, `class_ro_t`, and 12-byte relative `__objc_methlist` records, with original selector strings decoded from selref pointer targets; checked implementation with `llvm-objdump` disassembly. This investigates imported superclass from OX-099; not device v12.35 data.

- `_OBJC_CLASS_$_TTAStatusViewCombinedViewModel` is defined at **`0x65BC388`**. Its class data points to class_ro_t **`0x645EBE0`**, whose method-list pointer resolves to **`0x4B73A08`**. Header `0x8000000C`, count **60 instance methods**.
- Method-list entry index 0: **`initWithStatusViewModel:options:account:scribeContext:cardAttachmentDecider:` → IMP `0x2CDA960`**. Entry 53: **`options` → IMP `0x2CDD304`**; adjacent getters: `statusViewModel` → `0x2CDD2FC`, `account` → `0x2CDD30C`, `scribeContext` → `0x2CDD314`.
- Initializer directly retains `x3` options into **`x24`** at `0x2CDA988`. It checks original model `x19` and account `x20` for nonnull at `0x2CDA9B8..0x2CDA9BC`; thus successful initialization is conditional.
- In the successful initialization branch, **`0x2CDA9F8: str x24, [x23,#0x50]`** writes the original options value to instance offset **`+0x50`**. Getter `0x2CDD304: ldr x0,[x0,#0x50]`; `0x2CDD308: ret` reads the exact same field. This proves actual storage and retrieval, not just argument forwarding or a guessed ivar.
- Other retained fields on this branch: status view model at `+0x48`, account at `+0x58`, scribe context at `+0x60`, card-attachment decider at `+0x78`. Their exact ownership/lifetime concerns are separate from the option-value observation.

**Interpretation:** The OX-097 generator → OX-098/099 subclass super-dispatch → this XAppLibraries superclass initializer chain now has a concrete options storage point. No bit decoding was observed inside the inspected initializer. **Still unresolved:** readers of `options`, per-bit semantics, propagation to final body view `displayType` and height, and official v12.35 runtime conditions.

**Reproduce:** Extract `XAppLibraries` from the source IPA and inspect `llvm-objdump -d --start-address=0x2cda960 --stop-address=0x2cdaaac XAppLibraries` and `llvm-objdump -d --start-address=0x2cdd2fc --stop-address=0x2cdd31c XAppLibraries`. Decode class `0x65BC388` → class_ro_t `0x645EBE0` → method list `0x4B73A08`, relative entry 0 and 53.

Research-only change; no Scarlet X app, Probe, main branch or version changes.


## OX-101 / OX-102 — Verify combined-view-model adjacent hash call and options getter (2026-10-22)

**Primary evidence:** Original user-provided X v12.25 IPA, extracted `XAppLibraries.framework/XAppLibraries`. Direct ARM64 disassembly and native Mach-O `__objc_selrefs` chained rebases, verified against original C strings.

- `_TTAStatusViewCombinedViewModelIsEqual` starts at **`0x2CDBB6C`**, with a distinct function following at **`0x2CDBC90`**. Do not merge these function bodies.
- The latter function reads `self+0x48` at `0x2CDBCA4` and `self+0x58` at `0x2CDBCB4`, using ObjC stub **`0x4A8CAC0`** for both objects. Stub selector ref **`0x650F1F8`** rebases to **`0x58500D0`**, containing the exact selector **`hash`**. It computes **`37 * hash(self+0x48) + hash(self+0x58) + 23273`** at `0x2CDBCBC..0x2CDBCC4`. It does not directly load `self+0x50` (options), although function owner and callers need more investigation.
- Independently, the known **`options`** accessor at **`0x2CDD304`** directly loads `[x0,#0x50]` and returns. The `options` selector is independently confirmed at ObjC stub **`0x4AB2700`** → selector reference **`0x6518908`** → rebase **`0x579D128`** (`options`).
- **Boundary:** The adjacent function's hash-like computation is now backed by actual `hash` message sends. This does not prove how the options bits affect layout, nor that all hashing/equality code ignores options. The exact call owners and option-consuming methods remain to trace.

**Reproduce:** `llvm-objdump -d --start-address=0x2cdbb6c --stop-address=0x2cdbcd8 XAppLibraries`; `llvm-objdump -d --start-address=0x4a8cac0 --stop-address=0x4a8cad4 XAppLibraries`; `llvm-objdump --macho --dyld-info XAppLibraries` and confirm refs `0x650F1F8`, `0x6518908`.

Only documentation updated; no application, Probe, main or version changes.


## OX-103 — Stored options participates in combined-view-model equality (2026-10-22)

**Primary evidence:** Original supplied X v12.25 IPA, `XAppLibraries.framework/XAppLibraries` extracted and scanned directly for ARM64 BL instructions. The stub `0x4AB2700`, previously resolved in OX-102 to the ObjC selector `options`, has **77 direct BL callsites** in the executable `__TEXT,__text` section (`0x4000..0x4A33508`). These are callsites, not distinct methods, and neither dynamic dispatch nor indirect calls are covered.

**Concrete consumer confirmed:** Function `_TTAStatusViewCombinedViewModelIsEqual` at `0x2CDBB6C` includes `0x2CDBBFC: mov x0,x19`, **`0x2CDBC00: bl 0x4AB2700`** (options getter), **`0x2CDBC04: cmp x0,x23`**, and **`0x2CDBC08: b.ne 0x2CDBC38`**. The x23 comparison operand came from incoming x2 at `0x2CDBB88`; a mismatch takes the not-equal branch and sets result false at `0x2CDBC38`. This proves that the `options` value participates in this equality routine.

**Relation to OX-101/102:** The adjacent separate function at `0x2CDBC90` hashes the model and account fields without a direct options read in that short function. That observation must **not** be generalized to the equality routine, which demonstrably does read and compare options.

**Boundary:** Equality-sensitive options are not proof of an options-to-body-`displayType` transformation or a particular text-height calculation. Next inspect relevant direct consumers within the `0x2CBB...` layout routines and classify masks by their actual receiver and dataflow. Official v12.35 runtime remains unverified.

**Reproduce:** `llvm-objdump -d --start-address=0x2cdbb6c --stop-address=0x2cdbc64 XAppLibraries`; cross-check `options` selector stub `0x4AB2700`. Scan executable ARM64 BL imm26 targets for destination `0x4AB2700`.

Documentation only. SCARLET-X production app, Probe, version and `main` branch unchanged.


## OX-104 — Multiple options-dependent classification calls near combined-view-model presentation setup (2026-10-22)

**Primary evidence:** Original user-provided X v12.25 IPA `XAppLibraries.framework/XAppLibraries` ARM64 executable (124,141,728 bytes), disassembled directly with `llvm-objdump`. Starting with OX-103's ObjC `options` stub `0x4AB2700`, independently scanned the full executable for directly targeting ARM64 BL instructions and recovered **77** callsites, including a dense cluster at `0x2CBB708..0x2CC0BF4`. This scan counts direct call instructions only, not the number of methods or actual runtime invocations.

Concrete sample at `0x2CBC680..0x2CBC750`:
- `0x2CBC68C..0x2CBC694` sends `options` to the object retained in x19, then forwards its result as **x3** into helper **`0x2CC6D80`**, with x0 from a separate getter call and x1/x2 from retained values.
- The helper's returned x0 is compared to **1** at `0x2CBC6A8`; a Boolean equal-result is forwarded to another ObjC method call.
- The same receiver's `options` is read again at `0x2CBC6C8`, passed to **the same helper**, and compared to **4** at `0x2CBC6E0`.
- A third `options` getter call at `0x2CBC700` again feeds helper `0x2CC6D80`, whose result is compared to **3** at `0x2CBC718`.
- A fourth options call at `0x2CBC738` feeds another downstream call at `0x2CBC750`, showing repeated use beyond the three equality checks.

**Established:** This region reads saved options and repeatedly passes them into a common classifier/helper, then branches on its result. **Unresolved:** exact owner of the containing method, identity and behavior of helper `0x2CC6D80`, whether return values 1/4/3 correspond to any body displayType or a different enum, and whether these presentation calls are used by standard home posts. Do not identify numeric return values as text renderer modes without resolving the helper's actual inputs/output.

**Reproduce:** `llvm-objdump -d --start-address=0x2cbc680 --stop-address=0x2cbc760 XAppLibraries`, followed by `llvm-objdump -d --start-address=0x2cc6d80 --stop-address=0x2cc6e70 XAppLibraries`. No production application/Probe/version or main-branch changes.


## OX-105 — Decode options-driven classifier at 0x2CC6D80 (2026-10-22)

**Primary source:** User-supplied official X v12.25 IPA, original `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries`; extracted anew and disassembled directly using `llvm-objdump`. This continues OX-104, which identified calls to the same helper and comparisons against 1/4/3.

- The function at **`0x2CC6D80`** saves input arguments `x0` into x22, `x1` into x19, `x2` into x20 and **`x3` (options) into x21** at `0x2CC6DA0..0x2CC6DAC`.
- At **`0x2CC6DC0`**, `tbnz x21,#0x3b,0x2CC70A0` branches when **options bit 59** is set. At `0x2CC6DD4..0x2CC6DE4` it builds mask `0x2000400000000000` and tests `options & mask`; the nonzero branch differs from the zero branch. This is a direct options-sensitive decision.
- At `0x2CC6E68..0x2CC6E74` the helper compares its **first argument x22** to values 4 and 2, gating a following path; these are *input* comparisons, not returned values.
- At `0x2CC6F44` it can set **return candidate 1**; at `0x2CC7088` **3**; and at `0x2CC70B4..0x2CC70BC` it selects **4 or 0** depending on the Boolean result of sub-helper **`0x2CC72C8`**. It returns selected x21 via x0 at `0x2CC70D0`.
- The sub-helper `0x2CC72C8` also receives x3 as options and begins examining bits **59 and 60**, plus a composite bitmask at `0x2CC7304..0x2CC732C`. Its exact semantics and all downstream branches remain to be decoded.
- Disassembler labels in this broad region may refer to enclosing nearest symbols rather than the local function; the input-output description here follows actual instructions and boundaries instead of guessing a function name.

**Confirmed:** the helper identified in OX-104 reads the incoming options, makes flag-dependent decisions, and yields classification codes that can include 0/1/3/4; this supports interpreting the nearby OX-104 comparisons as checks against a classifier. **Not proven:** the semantic enum name, correspondence to `TTAStatusBodyTextView` displayType, the official X v12.35 runtime option values, and a specific text-height effect.

**Reproduce:** `llvm-objdump -d --start-address=0x2cc6d80 --stop-address=0x2cc7100 XAppLibraries` and `llvm-objdump -d --start-address=0x2cc72c8 --stop-address=0x2cc7360 XAppLibraries`.

Documentation only, no app/Probe/main/version changes.


## OX-106 — Bit gates in helper 0x2CC72C8 (2026-10-22; delayed entry)

**Source:** Original official X v12.25 XAppLibraries Mach-O. At `0x2CC7304` the helper extracts options bit 59. It tests option mask `0x2000004000000000` (bits 61 and 38); either bit set branches to Boolean false. The helper then requires input x22==2 or bit59 set. If bit59 is set it returns bit60; otherwise it enters an extended predicate path. Common return at `0x2CC7560` masks the result to one bit (`and w0,w23,#1`). This helper is Boolean, distinct from the outer classifier's multi-valued result. Semantics of the bits remain unverified. Native disassembly: `llvm-objdump -d --start-address=0x2cc72c8 --stop-address=0x2cc7578 XAppLibraries`.

## OX-107 — Decode extended predicate calls: promotion/boost feature path (2026-10-22)

**Primary source:** User-provided original official X v12.25 IPA `XAppLibraries.framework/XAppLibraries`. ARM64 code inspected at `0x2CC7330..0x2CC7550`, corresponding objc stub `adrp/ldr` selector refs decoded through Mach-O chained-rebase words and selector strings. Following are **directly resolved selector strings** with exact calls:

| Call stub | Selector |
|---|---|
| `0x4AC35C0` | `representedStatus` |
| `0x4A5DDA0` | `accountID` |
| `0x4A83CE0` | `featureSwitchesForAccountID:` |
| `0x4AA2C20` | `isTweetedByAuthenticatedAccount` |
| `0x4A68400` | `boolForKey:` |
| `0x4AA17A0` | `isQuoteStatus` |
| `0x4AEEA40` | `superFollowInfo` |
| `0x4AA6240` | `limitedActions` |
| `0x4A75FA0` | `count` |
| `0x4AA15C0` | `isPromoted` |
| `0x4ABDC60` | `quickPromoteEligibility` |
| `0x4A9E8E0` | `isEligibleForPromotion` |
| `0x4AA1D60` | `isRunningPromotion` |
| `0x4AA2B40` | `isTweetPromoteButtonInFocalTopToolbarEnabled` |
| `0x4AA2B00` | `isTweetPromoteButtonBoostAgainInAuthorViewEnabled` |
| `0x4AA27C0` | `isThirdPartyBoostAuthorViewButtonEnabled` |

These selector names establish that the extended predicate checks tweet identity, feature switches, promotion eligibility/current promotion, and Boost button flags. At `0x2CC73A0`, the return of `isTweetedByAuthenticatedAccount` gates a branch; a series of `boolForKey:` tests and the promotion-related selector checks control later branches. An explicit `0x2CC753C` path sets Boolean false before common return.

**Interpretation correction:** This is strong evidence of a *promotion/Boost button eligibility* path rather than text-body renderer selection. The precise owner of `0x2CC72C8`, each `boolForKey:` key, and its connection (if any) to the outer 0/1/3/4 classifier still require proof. Do **not** label the numeric classifier outputs as `TTAStatusBodyTextView.displayType`. This path is deprioritized for the goal of matching ordinary home-timeline body text heights unless stronger evidence links it to text rendering. Static original v12.25 only, no official v12.35 runtime confirmation.

**Reproduce:** disassemble `0x2cc7330..0x2cc7570` and listed objc stubs in original XAppLibraries, resolve each stub's `__objc_selrefs` slot with Mach-O chained rebases into `__objc_methname`.

Research only. SCARLET-X app, Probe, main and versions unchanged.


## OX-108 — Recheck real body-height method displayType split, rather than promote-button classifier (2026-10-22)

**Primary source:** Original user-provided official X v12.25 IPA; freshly extracted `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries`. Verified `objc_methods` SQLite record for selector `heightForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:richTextEnabled:trailingString:maxLines:attachmentDelegate:textKit2Enabled:cachingEnabled:` (binary_id 2, IMP **`0x2CCC9EC`**) and disassembled its original ARM64 instructions at `0x2CCC9EC..0x2CCCBC0`.

- Incoming `displayType` is retained from x5 into x23 at **`0x2CCCA18`**. The function checks it against **6** at `0x2CCCADC` and branches when greater.
- For values 0..6, `0x2CCCAE4..0x2CCCAF4` computes **`(1 << displayType) & 0x79`**, branching when the result is zero. Mask `0x79 = 0b1111001` selects **displayType 0, 3, 4, 5, 6**; values **1 and 2** instead go to `0x2CCCB38`. Values greater than 6 branch to `0x2CCCB7C`; do not infer their semantics from this out-of-range path.
- For types 0/3/4/5/6, the code sets further parameters on x22 at `0x2CCCAFC..0x2CCCB10` and calls **`0x4A64BE0`** at `0x2CCCB1C`, then converts its returned integer to a floating value (`scvtf d0,x0`). The precise callee name should be resolved from native imports/selector stubs before assigning it a text-measurement API label.
- For types 1/2, it calls **`0x4A64BC0`** at `0x2CCCB40` and conditionally uses the resulting object in **`0x4AE9820`** at `0x2CCCB68`; the fallback when null yields zero at `0x2CCCB80`. The callee identities and return semantics remain to verify.
- This independent body-height method is a much more targeted research lead than the `0x2CC72C8` promotion/Boost predicate from OX-107. It agrees with the *existence of a 0/3/4/5/6 vs 1/2 split* previously noted in OX-019, without yet establishing official X v12.35 live mode, exact font, line wrapping or observed pixels.

**Reproduce:** `llvm-objdump -d --start-address=0x2ccc9ec --stop-address=0x2cccbc0 XAppLibraries`. Cross-check the IMP in SQLite with `SELECT imp FROM objc_methods WHERE selector LIKE 'heightForViewModel:options:displayTextOptions:%';`. Do not use objdump's nearest symbol label as the owner name: the exact method identity comes from native/indexed ObjC metadata.

Documentation only: no Scarlet X app, Probe, main or version changes.


## OX-109 — Resolve both body-height branch selector targets (2026-10-22)

**Primary evidence:** Original user-provided official X v12.25 IPA, freshly extracted `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries` (124,141,728 bytes). Native `llvm-objdump -d` of body-height IMP `0x2CCC9EC` and its three ObjC dispatch stubs; selector reference pointers verified against `llvm-objdump --macho --dyld-info` chained rebases and NUL-terminated text in `__TEXT,__objc_methname`.

- The displayType 0/3/4/5/6 path calls stub **`0x4A64BE0`** at **`0x2CCCB1C`**. Stub loads selector ref **`0x6505240`** → text **`0x581490B`**: **`attributedTextModelHeightForOptions:`**. The integer result is converted to floating point at `0x2CCCB20`.
- The displayType 1/2 path calls stub **`0x4A64BC0`** at **`0x2CCCB40`**. Stub loads selector ref **`0x6505238`** → text **`0x58148EC`**: **`attributedTextModelForOptions:`**. After retaining the returned model, a subsequent dispatch at **`0x2CCCB68`** targets stub **`0x4AE9820`**, whose selref **`0x6526550`** → text **`0x58D8533`**: **`sizeForAttributedTextModel:width:textKit2Enabled:`**.
- The native `__objc_methname` section has VM starting `0x5765340` and file offset `91640640` in this Mach-O; for these three strings the file offsets happen to coincide numerically with VM addresses. Decoding was validated from original bytes rather than nearest disassembler symbol labels.
- **Established:** explicit split between height-from-attributed-model and obtaining model then measuring its size. **Not established:** exact implementation ownership of those three selectors, attributed-model-height caching and invalidation, how the size helper uses textKit2Enabled, final rounding and measured values, actual v12.35 displayType.

**Reproduce:**
```sh
llvm-objdump -d --start-address=0x2cccae0 --stop-address=0x2cccb90 XAppLibraries
llvm-objdump -d --start-address=0x4a64bc0 --stop-address=0x4a64c00 XAppLibraries
llvm-objdump -d --start-address=0x4ae9820 --stop-address=0x4ae9840 XAppLibraries
llvm-objdump --macho --dyld-info XAppLibraries | grep -E '0x6505238 |0x6505240 |0x6526550 '
```

Research documentation only; no Scarlet X app, Probe, main branch, or version changes.


## OX-110 — Concrete attributedTextModelHeightForOptions: has conditional measurement and upward rounding (2026-10-22)

**Primary evidence:** Unmodified user-provided official X v12.25 IPA, `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries` (124,141,728 bytes). Fresh extraction; `scarlet_macho(1).sqlite` checked and native `llvm-objdump -d --start-address=0x96e3c4 --stop-address=0x96e658 XAppLibraries` independently inspected.

- The `objc_methods` index has a concrete `attributedTextModelHeightForOptions:` IMP **`0x96E3C4`** (binary_id 2; list `0x4B67D78`), **as well as numerous other entries** with the same selector. The latter can include separate owners or declaration records. The following conclusions are specifically about the executable method at `0x96E3C4`, not every possible receiver.
- At `0x96E3E4..0x96E3F8` the method retains the incoming options object in x19 and calls a property/getter stub returning double in d0. It compares with zero at `0x96E3FC`; if the value is not positive it branches to a zero-height return (`0x96E46C..0x96E470`). The exact property selector must be decoded before naming this width/size constraint.
- There are conditional early-return/cache-like paths at `0x96E440..0x96E468`, including a call at `0x96E454` and a value converted to signed 64-bit via `fcvtzs x22,d0` at `0x96E464`; the exact semantics and whether this is a cache hit require resolving call targets.
- The longer measurement path starting `0x96E550` obtains a model through **`attributedTextModelForOptions:`** at `0x96E56C` (selector stub `0x4A64BC0`, previously resolved in OX-109). The following calls handle a measurement/model object and a conditional fallback (`0x96E590..0x96E5D8`).
- In the measurement-success path, the method calls `0x4A5EB40` at `0x96E5EC`, converts a double result to float (`fcvt s0,d1` at `0x96E5F0`), performs **`frintp s8,s0` at `0x96E5F4`** (round toward positive infinity), then **`fcvtzs x22,s8` at `0x96E618`** before return at `0x96E644`. This directly demonstrates a float32 upward-rounding stage for this path, consistent with but not identical to the earlier fit-to-size analysis.
- Some branches return zero or another integer without traversing the `frintp` path. Therefore do not assert a universal rounding formula or label the return as the final cell height; this method supplies one attributed-model height input, conditional on options and internal helpers.

**Next:** Resolve native selector stubs `0x4B016C0`, `0x4AF0D20`, `0x4A6BD20`, `0x4A5EB40` and cache-related calls, then identify the receiver/class owner of this IMP from original `class_ro_t` metadata. Cross-check with OX-109's calling displayType path. Original X v12.25 only; no live X v12.35 measurement.

No app/Probe/main/version change.


## OX-111 — Resolve width, caching and cached-height selectors in attributed model height routine (2026-10-22)

**Primary evidence:** User-supplied unmodified official X v12.25 IPA `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries` (124,141,728 bytes), extracted anew. ARM64 code disassembled at `0x96E3C4..0x96E644`; individual Objective-C stubs decoded to native `__objc_selrefs` and resolved using `llvm-objdump --macho --dyld-info` chained rebases and original selector strings.

| Stub | Selector ref → native selector | Callsite |
|---|---|---|
| `0x4B016C0` | `0x652C4F8` → **`width`** | `0x96E3F8`, `0x96E5DC` |
| `0x4AF0D20` | `0x6528290` → **`textOptions`** | `0x96E408` |
| `0x4A6BD20` | `0x6506E90` → **`cachingEnabled`** | `0x96E444`, `0x96E5FC` |
| `0x4AF0BC0` | `0x6528238` → **`textHeight`** | `0x96E460` |
| `0x4A5EB40` | `0x6503A18` → **`actualSize`** | `0x96E5EC` |
| `0x4A58460` | `0x6502060` → **`_tfn_displayTextCacheEntryForOptions:prepopulateDisplayTextCacheIfDoesNotExist:`** | `0x96E418` |
| `0x4AF0700` | `0x6528108` → **`text`** | `0x96E428` |
| `0x4AAC8C0` | `0x6517178` → **`mutableCopy`** | `0x96E554` |

**Verified branch interpretation:** At `0x96E3F4..0x96E400`, width is compared with floating 0.0 using `fcmp d0,#0.0` then `b.ls`; when width is not ordered-greater-than-zero, the branch sets integer height 0 at `0x96E46C`. The ordered-greater-than-zero branch requests text options and the display-text cache entry. At `0x96E440..0x96E468`, `cachingEnabled` must be true and helper `0x96E694` must return nonzero before returning `textHeight` via `fcvtzs x22,d0`. Hence the short path reads existing text height (not proven to be a valid hit without helper analysis). Otherwise the routine measures an attributed model, obtains `actualSize` and rounds upward using `frintp s8,s0` (OX-110). A later `cachingEnabled` check gates helper `0x96EAC8`, likely involved in persistence but not yet verified.

**Limits:** Exact predicate in `0x96E694`, how cache entries are populated/invalidated, and precise type/field semantics of the `actualSize` return need separate confirmation. This is not a universal formula for final timeline row height, and v12.35 device behavior remains unmeasured.

**Reproduce:** `llvm-objdump -d --start-address=0x96e3c4 --stop-address=0x96e658 XAppLibraries` and corresponding ObjC stubs; `llvm-objdump --macho --dyld-info XAppLibraries` for listed selector refs.

Documentation only. Scarlet X production code, Probe, main branch and versions unchanged.


## OX-112 — Cache validation and post-measurement helper control flow (2026-10-22)

**Primary source:** Original user-provided official X v12.25 IPA, unmodified `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries` (124,141,728 bytes), freshly extracted and disassembled with native `llvm-objdump`. Focused on OX-111's two local helpers `0x96E694` and `0x96EAC8`. Nearest broad objdump symbol names are not assumed to identify these local functions.

**Cache-read gate from caller `0x96E3C4`:** width is required to pass ordered `>0` at `0x96E3F8..0x96E400`. The routine obtains a display-text cache entry; `cachingEnabled` must be nonzero at `0x96E444..0x96E448`; helper `0x96E694` must return nonzero at `0x96E454..0x96E458`. Only then does the caller read `textHeight` and integer-convert it at `0x96E460..0x96E464`.

**Validation helper `0x96E694`:** It receives a cache entry in x0 and options in x1; retains both at `0x96E6BC..0x96E6C0`. It obtains options `width` at `0x96E700`, converts it to an unsigned integer `fcvtzu x8,d0` at `0x96E704`, and packs a portion using `and x28,x8,#0xfff` at `0x96E714`. Another float-derived integer is shifted/packed at `0x96E7B8`. It compares an object/string-derived pair at `0x96E78C`; calls an equality-like ObjC stub at `0x96E7A8` only when both compared objects are nonnull. It performs multiple symmetric floating comparisons with a loaded constant `d11` at `0x96E82C..0x96E8D0`, and at `0x96E954..0x96E968` compares d8/d9 using `d11` as a tolerance. It also checks `textHeight` against floating 0 at `0x96E928..0x96E930`, compares a stored packed/integer value to current x28 at `0x96E938..0x96E950`, and combines additional Boolean predicates before eventual return. This is a **multi-condition validity check**, not merely a `cachingEnabled` flag check. Exact property names for each underlying metric, tolerance constant, and precise total predicate remain to decode.

**Post-measurement `0x96EAC8`:** Caller `0x96E604..0x96E614` passes x0=cache entry, x1=options, x2=measured object, and double d0 obtained from the rounded single-precision height; call occurs only if `cachingEnabled` is true. Inside helper, x0/x1/x2 are retained into x19/x20/x21 and d0 into d8 (`0x96EAEC..0x96EAF4`). It queries options width at `0x96EB40`, checks d8 != 0 at `0x96EB58..0x96EB5C`, and performs further processing. The code contains additional conditional calls and does **not** establish a direct write to a named height property without selector identification. This is therefore a **post-measurement cache-update candidate**, not yet fully confirmed as a height setter.

**Interpretation:** Cache reuse depends on substantial content/metric compatibility, explaining why equal width alone need not imply a reusable height. The precise reuse predicate, cache invalidation and update assignments remain unresolved. All findings refer to static official X v12.25, not live v12.35 results or final timeline-cell height.

Reproduce:
```sh
llvm-objdump -d --start-address=0x96e3c4 --stop-address=0x96e470 XAppLibraries
llvm-objdump -d --start-address=0x96e694 --stop-address=0x96eac8 XAppLibraries
llvm-objdump -d --start-address=0x96eac8 --stop-address=0x96ee74 XAppLibraries
```
Research only; application, Probe, versions and main unchanged.


## OX-113 — Confirm post-measurement cache writes and seed metric setters (2026-10-22)

**Primary evidence:** Original user-supplied official X v12.25 IPA, extracted `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries`. ARM64 instructions directly disassembled at `0x96EAC8..0x96EE70`; Objective-C stubs and rebased `__objc_selrefs` resolved against original NUL-terminated strings. This advances OX-112 from an update *candidate* to concrete setters.

- Helper `0x96EAC8` retains **x0 cache entry in x19**, **x1 options in x20**, **x2 measured model in x21**, and floating-point **d0 height in d8**. At `0x96EB58`, it branches depending on whether d8 is zero. The zero-height branch runs separate diagnostic/assert-like calls, then exits without reaching the normal setter sequence; the precise diagnostics remain to be identified.
- For a nonzero height, the helper derives packed data from numeric values (including width and a value multiplied by 10) at `0x96EBDC..0x96EBF0`. At `0x96EBF4`, x0 is the **cache entry**, and the setter sequence begins.
- The following **confirmed selector stub → rebased selector name** pairs operate on that same cache entry:
  - `0x96EBF8` → stub `0x4ADF200` → **`setSeed:`**.
  - `0x96EC38` → `0x4ADF240` → **`setSeedFontName:`**.
  - `0x96EC70` → `0x4ADF280` → **`setSeedLineSpacing:`**.
  - `0x96EC98` → `0x4ADF2A0` → **`setSeedEmptyLineMaxHeight:`**.
  - `0x96ECC0` → `0x4ADF220` → **`setSeedLineHeight:`**.
  - `0x96ECE8` → `0x4ADF260` → **`setSeedKerning:`**.
  - `0x96ECFC` → stub `0x4AE21C0` → **`setTextHeight:`** with x0=x19 cache entry, and d0 restored from d8.
  - `0x96ED10` → stub `0x4AE22E0` → **`setTextModelColorStateIdentifier:`** (derived from measured model).
  - `0x96ED1C` → stub `0x4AE2240` → **`setTextModel:`** with x0=x19 cache entry and x2=x21 measured model.
- These native calls establish that the **successful nonzero-measurement path writes height, text model and multiple seed metrics to a cache-entry receiver**. It goes beyond the OX-112 tentative identification, but does not yet prove storage durability, eviction/invalidation policy or full equivalence predicate in `0x96E694`.
- Note a later `0x96ED60` setter `0x4AE2260` exists in a diagnostic/assert-related region; do not describe it as always executed in the normal path without tracing its branch.

**Reproduce:** `llvm-objdump -d --start-address=0x96eac8 --stop-address=0x96ee74 XAppLibraries`; `llvm-objdump -d --start-address=0x4adf200 --stop-address=0x4adf2bc XAppLibraries`; `llvm-objdump -d --start-address=0x4ae21c0 --stop-address=0x4ae2290 XAppLibraries`; inspect dyld-info selrefs `0x6523BC8..0x6523BF0` and `0x65247B8..0x65247E0`.

Static official X v12.25 only; no X v12.35 device validation. No SCARLET-X app/Probe/main/version changes.


## OX-114 — Resolve cache validity accessors against saved seed metrics (2026-10-22)

**Primary evidence:** User-provided original X v12.25 IPA; directly extracted `XAppLibraries.framework/XAppLibraries`. Disassembled helper `0x96E694..0x96E9D0` with `llvm-objdump`. Verified Objective-C stub selrefs against original Mach-O `--dyld-info` chained rebases and the corresponding native selector C strings.

**Confirmed cache-entry getters in validation helper:**

| Native call | Resolved selector |
|---|---|
| `0x96E770` → stub `0x4AC8CC0` | `seedEmptyLineMaxHeight` |
| `0x96E7D0` → stub `0x4AC8D00` | `seedLineHeight` |
| `0x96E800` → stub `0x4AC8D20` | `seedKerning` |
| `0x96E850` → stub `0x4AC8CA0` | `seedFontName` |
| `0x96E898` → stub `0x4AC8CE0` | `seedLineSpacing` |
| `0x96E938` → stub `0x4AC8C80` | `seed` |
| `0x96E98C` → stub `0x4A9F820` | `isHashflagVersionValid` |
| `0x96E994` → stub `0x4AA27A0` | `isTextModelColorStateIdentifierValid` |

**Corresponding source-option getters:**
- `0x96E7F0` → stub `0x4AA62E0`: `lineHeight`
- `0x96E81C` → stub `0x4AA6320`: `lineSpacing`
- `0x96E86C` → stub `0x4A80960`: `emptyLineMaxHeight`
- `0x96E8B4` → stub `0x4AA4000`: `kerning`
- `0x96E700` → stub `0x4B016C0`: `width`

**Additional verified control flow:** At `0x96E704..0x96E7B8`, the helper converts width and a second floating-point parameter (scaled by ten) to integers and packs them into a 24-bit portion of a seed value using `and #0xfff` and `bfi #12,#12`. A cached `seed` is compared to the constructed value at `0x96E938..0x96E950`. At `0x96E820..0x96E8D0`, a tolerance `d11` is used in several pairwise double comparisons. A `textHeight` nonzero check occurs at `0x96E928`. Other conditions, including the two validity predicates, are combined before returning; do not interpret this as every seed value needing strict bit-for-bit equality.

**Interpretation:** The same kinds of seed metrics that OX-113 observed being written to a cache entry are subsequently read and checked by this validator. The precise tolerance value, class/method owner, and complete Boolean reduction remain to verify, as does runtime behavior in official v12.35. No claim about final row height or all posts is implied.

**Reproduce:** `llvm-objdump -d --start-address=0x96e694 --stop-address=0x96e9d0 XAppLibraries`, plus the indicated stub addresses and `llvm-objdump --macho --dyld-info XAppLibraries` rebases. No app/Probe/main/version changes.


## OX-115 — Confirm cache comparison tolerance 0.001 and Boolean reduction (2026-10-22)

**Primary evidence:** Original user-supplied official X v12.25 IPA, native `XAppLibraries.framework/XAppLibraries` disassembled directly. Helper `0x96E694..0x96EAC4` inspected with `llvm-objdump`; numeric constant read directly from the binary via `struct.unpack('<d', ...)`.

- At **`0x96E820`**, `adrp x8,0x4C15000`; at **`0x96E824`**, `ldr d11,[x8,#0xF18]` loads a 64-bit double at **`0x4C15F18`**. The original bytes are `fc a9 f1 d2 4d 62 50 3f`, little-endian IEEE-754 **0.001**.
- For three double-valued formatting metrics, instructions `0x96E828..0x96E840`, `0x96E870..0x96E888` and `0x96E8B8..0x96E8D0` respectively compare a current value and cached value with symmetric tolerance: `current <= cached + 0.001` **and** `cached <= current + 0.001`. The comparisons use `fcmp`, `cset le`, `csel ... gt`, so NaN/unordered handling should be analyzed separately before reducing these unconditionally to absolute-difference formulas.
- At **`0x96E954..0x96E968`** a fourth pair in `d8/d9` is checked analogously, with `b.gt` rejecting either excess. These registers originate from earlier metric getters; do not assign their semantic names without decoding their exact call targets.
- The cached `textHeight` must be nonzero: `0x96E928..0x96E930`. The packed `seed` must equal the locally constructed x28 **and** the object/font-name comparison flag w23 must hold (`0x96E938..0x96E950`), or the function returns false.
- After the fourth tolerance comparison, it checks for a nonnull cache text/model object and obtains **`isHashflagVersionValid`** and **`isTextModelColorStateIdentifierValid`**. At **`0x96E998..0x96E9B0`**, an equality check between two additional x25/x26 objects is combined with three saved tolerance Boolean flags and the color-state validity result to form the returned w24; the hashflag validity check provides an early-false branch. The exact meaning of the compared object pointers still needs selector-level confirmation.
- Return at `0x96EA9C`: `mov x0,x24` before epilogue. A diagnostic/logging conditional at `0x96E9CC..0x96EA7C` does not appear to overwrite the accumulated Boolean, but its logging semantics were not fully decoded.

**Interpretation:** A precise `0.001` double tolerance applies to four symmetric metric comparisons, in addition to seed, text/model identity/validity and cached nonzero height. Cache hits require more than same width or same text. Caution: this is static official v12.25 helper behavior; actual v12.35 usage and final timeline-row height not validated.

**Reproduce:** `llvm-objdump -d --start-address=0x96e694 --stop-address=0x96eac8 XAppLibraries`; read `<d` bytes at file offset `0x4c15f18` of this Mach-O (VM=file offset for this constant). No app, Probe, main or version changes.


## OX-116 — Resolve previously unnamed cache validation inputs: font point size, font name, maxLines, model (2026-10-22)

**Primary source:** Original user-supplied X v12.25 IPA `Payload/Twitter.app/Frameworks/XAppLibraries.framework/XAppLibraries`, unmodified. Native instructions at `0x96E694..0x96E9B4` disassembled and dispatch stubs' `adrp/ldr` selector slots resolved against `llvm-objdump --macho --dyld-info` rebases and original selector C strings. Comparison made with OX-113's cache setter at `0x96EBDC..0x96EBF8`.

**Newly resolved selector stubs:**
- `0x4A86200` (`selref 0x650D7C8`): **`fontOptions`**.
- `0x4A860E0` (`0x650D780`): **`font`**.
- `0x4A861E0` (`0x650D7C0`): **`fontName`**.
- `0x4AB6DE0` (`0x6519AC0`): **`pointSize`**.
- `0x4A9EE20` (`0x6513AD0`): **`isEqualToString:`**.
- `0x4AAA100` (`0x6516788`): **`maxLines`**.
- `0x4AF98C0` (`0x652A578`): **`unsignedIntegerValue`**.
- `0x4AF0D00` (`0x6528288`): **`textModel`**.

**Verified interpretation:**
1. At `0x96E6D0..0x96E6F8` the validator invokes options `fontOptions`, then `font`, then `pointSize`. At `0x96E6FC..0x96E7B8`, it extracts current `width`, converts it to unsigned integer, multiplies the font point size by ten, converts it to unsigned integer, retains the low 12 bits of width, and inserts the low 12 bits of ten-times-point-size at bits 12..23 of constructed x28. At `0x96E938..0x96E950`, this is compared against the cached `seed` plus a font name equality flag.
2. This construction agrees directly with the cache write helper's `0x96EBDC..0x96EBF8`: multiply **pointSize** (held in d9 in that function) by ten; convert, combine its 12 bits with 12 low width bits (d10), and invoke **`setSeed:`**.
3. At `0x96E728..0x96E7AC`, another font-options retrieval and `fontName` is compared with cached `seedEmptyLineMaxHeight` object at `0x96E770` using **`isEqualToString:`** if pointers differ; **the receiver pairing is unusual** (the selector getter name does not naturally imply a string). The exact object source chain and whether previous OX-114's field label was reliably resolved require renewed verification before confidently equating this comparison to seedFontName. Direct instruction and stub identity are separately recorded.
4. At `0x96E8DC..0x96E910`, cached `textModel` and live options are each sent **`maxLines`**, and the live value is additionally sent `unsignedIntegerValue`. x25 and x26 are compared for **pointer equality** at `0x96E998`; earlier result depends on what objects these methods return. Crucially, do not describe this as numeric maxLines equality: x25 derives from cached model's `maxLines` and x26 from current option's `maxLines` via `unsignedIntegerValue`; type semantics need further investigation.
5. The already identified line height, line spacing, empty-line maximum and kerning comparisons use exact double tolerance `0.001` (OX-115), while cache `textHeight`, `seed`, `isHashflagVersionValid`, `isTextModelColorStateIdentifierValid` and text/model presence gate return as previously documented.

**Boundary:** Getter names confirmed. Some receiver chains and `maxLines` conversion/pointer equality remain nonobvious; do not equate pointer comparisons to numeric equality without further evidence. This is v12.25 static analysis only, not proof of the runtime chosen path in v12.35.

**Reproduction:** `llvm-objdump -d --start-address=0x96e694 --stop-address=0x96eac8 XAppLibraries`; inspect listed `__objc_stubs`, `llvm-objdump --macho --dyld-info XAppLibraries` for slot addresses. Compare `0x96ebdc..0x96ebfc` in cache write helper. No application, Probe, main, or version changes.


## OX-117 — Resolve maxLines comparison as numeric equality in cache validator (2026-10-22)

**Source:** Original official X v12.25 `XAppLibraries` from user-provided IPA, ARM64 `llvm-objdump -d --start-address=0x96e8dc --stop-address=0x96e9b8`. This refines and partly corrects the uncertainty in OX-116.

- `0x96E8DC..0x96E8F4`: `cacheEntry.textModel.maxLines` via stubs `textModel` (0x4AF0D00) and `maxLines` (0x4AAA100) is held in x25; no object retain/conversion follows this return.
- `0x96E8F8..0x96E910`: `options.maxLines` obtained through the same `maxLines` stub; this returned object is retained into x27; its `unsignedIntegerValue` (stub 0x4AF98C0) is placed in x26. The object x27 is then released at `0x96E914..0x96E918`.
- `0x96E998`: `cmp x25,x26`, and `0x96E9B0`: `csel w24,wzr,w8,ne`. This is **numeric maximum-lines equivalence**, not a pointer-identity test, because one side has been explicitly unboxed from the option's number object and the other side is the direct integer result of the model getter.
- The predicate also combines other previously documented checks (cached nonzero height, packed seed, 0.001-tolerance metrics, hashflag and color-state validity).
- **Still unresolved:** the `0x96E770` cached-entry getter previously decoded as `seedEmptyLineMaxHeight` appears to return an object passed to `isEqualToString:` for comparison with live `fontName`. This mismatch deserves an independent native stub/receiver verification before claiming a definite font-name matching field. Do not silently reinterpret the strange selector identity.

**Result:** One formerly unresolved OX-116 comparison is resolved with instruction-level evidence; do not extrapolate to runtime home-timeline displayType/width on official v12.35. Static analysis only; no production/Probe/version modification.


## OX-118 — Correct off-by-one ObjC stub mapping in cache font-name and metric comparisons (2026-10-22)

**Primary evidence:** User-provided unmodified official X v12.25 `XAppLibraries.framework/XAppLibraries`, native `llvm-objdump` disassembly of `0x96E728..0x96E8D0` and ObjC stubs `0x4AC8C80..0x4AC8D20`. Each stub's `adrp x1; ldr x1,[x1,#offset]` was resolved via dyld chained rebase entries for exact `__objc_selrefs`, then read as NUL-terminated strings from original Mach-O. **Corrects inaccurate stub names in OX-114 and the follow-up caveat in OX-116/117.**

| Stub | Selector slot | Actual selector |
|---|---|---|
| `0x4AC8C80` | `0x651E268` | `seed` |
| `0x4AC8CA0` | `0x651E270` | `seedEmptyLineMaxHeight` |
| **`0x4AC8CC0`** | **`0x651E278`** | **`seedFontName`** (NOT `seedEmptyLineMaxHeight`) |
| `0x4AC8CE0` | `0x651E280` | `seedKerning` |
| `0x4AC8D00` | `0x651E288` | `seedLineHeight` |
| **`0x4AC8D20`** | **`0x651E290`** | **`seedLineSpacing`** (NOT `seedKerning`) |

**Exact corrected validator callsites:**
- `0x96E770` → `0x4AC8CC0` → **`seedFontName`**. The live `fontName` returned at `0x96E74C` is compared with this cached string by pointer shortcut `0x96E78C` and `isEqualToString:` at `0x96E7A8` if both non-null. The previous puzzling string-vs-numeric-field discrepancy is therefore **an erroneous earlier stub mapping, not evidence of unusual object types**.
- `0x96E7D0` → `0x4AC8D00` → `seedLineHeight`; compared against live `lineHeight` (`0x96E7EC`).
- `0x96E800` → `0x4AC8D20` → **`seedLineSpacing`**; compared against live `lineSpacing` (`0x96E81C`), tolerance 0.001.
- `0x96E850` → `0x4AC8CA0` → **`seedEmptyLineMaxHeight`**; compared against live `emptyLineMaxHeight` (`0x96E86C`), tolerance 0.001.
- `0x96E898` → `0x4AC8CE0` → **`seedKerning`**; compared against live `kerning` (`0x96E8B4`), tolerance 0.001.
- `0x96E938` → `0x4AC8C80` → `seed`; width/point-size-packed seed comparison remains as OX-116.

**Consequence:** All the previously questionable formatter-field pairing now matches ordinary, type-consistent string and double comparisons. This correction supersedes the erroneous cache-getter names/callsites in the OX-114 table and the uncertainty about `0x96E770` in OX-116/117. It does not undo the separately evidenced OX-115 0.001 threshold or OX-117 maxLines numeric match. Exact cache-invalidations and dynamic v12.35 behavior remain unverified.

**Reproduce:** `llvm-objdump -d --start-address=0x96e728 --stop-address=0x96e8d0 XAppLibraries`; `llvm-objdump -d --start-address=0x4ac8c80 --stop-address=0x4ac8d40 XAppLibraries`; inspect chained rebases for slots `0x651E268..0x651E290` via `llvm-objdump --macho --dyld-info XAppLibraries`.

Static research only. No app, Probe, main branch or version changes.


## OX-119 — Previous-layout equality gate in T1Twitter cell layout builder (2026-10-22)

**Primary source:** Original user-supplied official X v12.25 IPA; freshly extracted `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`. Verified the method IMP `0x2EF7C4` for `cellLayoutForViewModel:options:account:layoutMetrics:withPreviousLayout:` against `scarlet_macho(1).sqlite` `objc_methods`; directly inspected ARM64 disassembly `0x2EF7C4..0x2EF97C`. Static analysis, SE not required.

- The method preserves the preceding layout parameter x6 in x20 at `0x2EF7E0`, and stores other layout parameters in x19/x23/x22/x24. It obtains the generator through the class's `layoutStateGenerator` selector (`0x2EF820`, stub `0x1314CC0`), then sends `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` via stub `0x1314C80` at `0x2EF85C`, saving the resulting new layout state in x21. Both stubs' selectors were independently verified from `__objc_selrefs`.
- At `0x2EF830..0x2EF840`, the previous layout x20 is queried by a method stub whose concrete name was not resolved in this entry, yielding x26. The new state is passed to generator with x6=x26 at `0x2EF858`. Do not assume x26 is identical to previous layout object: it is a derived value.
- At `0x2EF890..0x2EF8A0`, the routine obtains another value from the prior-layout parameter and **compares it to new state x21**. Pointer equality branches to `0x2EF934`.
- If pointers differ, `0x2EF8A8..0x2EF8D8` obtains a property/value from the prior layout and sends **`isEqual:`** via ObjC stub **`0x130A0E0`** (`__objc_selrefs` slot **`0x1AAAA00`** rebases to native selector C string at **`0x1629780`**). Its argument x2 is new layout state x21. A true result branches to `0x2EF938`, while false enters allocation/build flow at `0x2EF8DC..0x2EF930`.
- The equality-success path `0x2EF938..0x2EF940` retains and returns previous-layout x20 as x23, subject to the normal teardown/return at `0x2EF944..0x2EF978`. When equality fails, it constructs a layout object and returns that instead. This establishes **prior layout object reuse when derived layout states are pointer-equal or `isEqual:`**.
- **Scope:** This is *cell-layout object* reuse, distinct from attributed text height caching analyzed in OX-110..118. Reuse of an object is not proof that all frames are immutable, nor that every runtime home-timeline post takes this method; v12.35 device-level behavior remains unverified.

**Reproduce:** `llvm-objdump -d --start-address=0x2ef7c4 --stop-address=0x2ef97c T1Twitter`; `llvm-objdump -d --start-address=0x130a0e0 --stop-address=0x130a100 T1Twitter`; `llvm-objdump --macho --dyld-info T1Twitter` and original `0x1629780` selector bytes. No app/Probe/main/version changes.


## OX-122 — Direct T1StatusCellLayout fields and accessor IMPs (2026-10-22)

**Source:** Original official X v12.25 T1Twitter framework extracted from user IPA. The class-ref from OX-121 (slot `0x1AD57C8`) points to class `0x1AEF348`, class_ro_t `0x1996F28`. Native class metadata read directly in original Mach-O.

The class's direct method list pointer is `0x13D3AA8`, using relative method entries; its five methods decode to:
- `statusOptions` IMP `0x2F30CC`, encoding `Q16@0:8`;
- `setStatusOptions:` IMP `0x2F30DC`, encoding `v24@0:8Q16`;
- `statusViewLayoutState` IMP `0x2F30EC`;
- `setStatusViewLayoutState:` IMP `0x2F30FC`;
- `.cxx_destruct` IMP `0x2F313C`.

The class's direct ivar list at `0x1996EB8` contains exactly two entries: `_statusOptions` (type `Q`, field offset pointer `0x1ADD81C`), and `_statusViewLayoutState` (type `@\"<TTACoreStatusViewLayoutState>\"`, offset pointer `0x1ADD820`). Property attributes in list `0x1996F00` confirm `statusOptions` = `TQ,N,V_statusOptions` and `statusViewLayoutState` = `T@\"<TTACoreStatusViewLayoutState>\",&,N,V_statusViewLayoutState`.

Thus the newly created layout container in OX-120/121 explicitly owns the status flags and status-view layout-state reference. It has **no direct declared size/contentEdgeInsets ivars or accessors in this class method list**; those may come from its superclass or other inherited behavior and require separate superclass identification. This evidence does not itself specify avatar/header/body frames.

**Reproduce:** For Mach-O with matching VM/file offsets read `class_ro_t` at `0x1996F28`, relative methods at `0x13D3AA8`, ivars at `0x1996EB8`, and property list at `0x1996F00`; dereference each relative method name through its `__objc_selrefs` slot. No app/Probe/main/version changes.


## OX-123 — Resolve T1StatusCellLayout superclass and actual size/insets storage (2026-10-22)

**Primary evidence:** Original user-provided official X v12.25 IPA. Original `T1Twitter.framework/T1Twitter` class object `0x1AEF348` superclass slot **`0x1AEF350`** is a dyld bind to **`XServiceLibraries:_OBJC_CLASS_$_TFNDataViewCellLayout`**. The actual `XServiceLibraries.framework/XServiceLibraries` was independently extracted from that *same IPA* (87 MB approx.) and its ObjC metadata inspected (no SE required).

**Superclass concrete definition:** `llvm-objdump --syms XServiceLibraries` locates **`_OBJC_CLASS_$_TFNDataViewCellLayout` at `0x4423D00`**. Its superclass binding at `0x4423D08` is `libobjc:_OBJC_CLASS_$_NSObject`; its `class_ro_t` pointer at `0x4423D20` rebases to **`0x41CB720`**. The class's ivar list at **`0x41CB680`** and property list at **`0x41CB6E8`** contain:

| Own ivar | Type encoding | Offset |
|---|---|---|
| `_objectIdentifier` | `@\"<NSCopying>\"` | **0x08** |
| `_size` | `{CGSize=\"width\"d\"height\"d}` | **0x10** |
| `_contentEdgeInsets` | `{UIEdgeInsets=\"top\"d\"left\"d\"bottom\"d\"right\"d}` | **0x20** |

Property list entries are `objectIdentifier` (`T@\"<NSCopying>\",&,N,V_objectIdentifier`), **`size`** (`T{CGSize=dd},N,V_size`), and **`contentEdgeInsets`** (`T{UIEdgeInsets=dddd},N,V_contentEdgeInsets`). Therefore the previously observed `setSize:` and `setContentEdgeInsets:` on `T1StatusCellLayout` (OX-120; not yet committed) have a **concrete superclass storage owner** rather than merely a presumed one. The subclass's direct fields remain `_statusOptions` and `_statusViewLayoutState` (OX-122).

**Reproduce:** `llvm-objdump --macho --dyld-info T1Twitter | grep '0x1AEF350'`; `llvm-objdump --syms XServiceLibraries | grep 'TFNDataViewCellLayout'`; inspect rebased class/data pointers at `0x4423D00..0x4423D20` and `class_ro_t` `0x41CB720`; decode ivar/property entry pointers in `0x41CB680..0x41CB720` with Mach-O chained-fixup rebases. These addresses apply to the original v12.25 libraries.

**Limits:** Defines where layout size/insets are stored, not actual runtime numerical inset values, child view frames, or how the cell applies them; v12.35 behavior remains unverified. OX-120 and OX-121 were documented conversationally but their earlier GitHub writes were blocked. This OX-123 entry contains the independently verified superclass/storage finding, without implying that those missing numbered entries were committed.

Documentation only, no SCARLET-X application, Probe, main branch or version changes.


## OX-124 — T1StatusCell applies contentView.bounds as status-view frame; sizeThatFits uses intrinsicContentSize (2026-10-22)

**Evidence:** Original official X v12.25 user-provided IPA, `T1Twitter.framework/T1Twitter` and `scarlet_macho(1).sqlite`. The same ObjC method list `0x13D37C0` registers `setCellLayout:` at **0x2F09F4**, `layoutSubviews` at **0x2F0B74**, `sizeThatFits:` at **0x2F0BE4**. Native `llvm-objdump` disassembly confirms executable bodies. Objective-C dispatch stubs' slots resolved against Mach-O dyld rebase + native `__objc_methname` selector bytes.

- In **`layoutSubviews`** at `0x2F0BA4`, the cell receives **`contentView`** via stub `0x12E5040` (selref `0x1AA15D8` → selector text `contentView`), retaining the returned view in x20. At `0x2F0BB8`, the routine sends **`bounds`** to x20 via stub `0x12DBCE0` (selref `0x1A9F100` → selector text `bounds`), yielding CGRect-style return registers. At `0x2F0BBC..0x2F0BC4`, it reads an instance-ivar offset from `0x1ADD804`, loads the contained view pointer from the cell, and sends **`setFrame:`** at **`0x2F0BC8`** via stub `0x133F080` (selref `0x1AB7DE8` → selector text `setFrame:`). Thus a cell-owned child view receives the **contentView.bounds** as its frame.
- In **`sizeThatFits:`** at `0x2F0BE4..0x2F0BF0`, the cell loads **the same ivar at offset slot 0x1ADD804** and tail-calls stub **`0x1306D60`**; its selref `0x1AA9D20` resolves to **`intrinsicContentSize`**. Therefore this `sizeThatFits:` implementation returns the child view's intrinsic size, ignoring the passed fitting size in its body.
- In **`setCellLayout:`** at `0x2F09F4..0x2F0A80`, the incoming layout is processed, a status-view layout-related result is propagated to that same child-view ivar at `0x1ADD804` through an ObjC call at `0x2F0A5C`. The exact dispatched selector at `0x13431A0` should be independently decoded before calling it a concrete layout setter.
- OX-123 established separately that `T1StatusCellLayout` inherits `_size` and `_contentEdgeInsets` storage from `TFNDataViewCellLayout`. The **`layoutSubviews` method analyzed here does not itself read those layout fields or the four edge inset scalars**: it fills its child view with `contentView.bounds`. This leaves *where* the insets are applied (e.g. inside child layout or upstream metrics) unresolved. Do not conflate inherited layout storage with a proven CGRectInset at this cell-level callsite.
- Static v12.25 only. Does not supply runtime home TL margins or final header/avatar/body coordinates and has not been validated on v12.35/SE.

**Reproduce:** `llvm-objdump -d --start-address=0x2f09f4 --stop-address=0x2f0a84 T1Twitter`; `llvm-objdump -d --start-address=0x2f0b74 --stop-address=0x2f0bf4 T1Twitter`; inspect native objc stubs at 0x12E5040, 0x12DBCE0, 0x133F080, 0x1306D60 and their chained selrefs. No app/Probe/main/version changes.


## OX-125 — Cell's setCellLayout: forwards derived statusViewLayoutState to child setLayoutState: (2026-10-22)

**Evidence:** Original user-provided X v12.25 IPA, `T1Twitter.framework/T1Twitter`. Native disassembly with `llvm-objdump` at `0x2F09F4..0x2F0B70`; native Objective-C stub references resolved via `llvm-objdump --macho --dyld-info` and original selector strings. SQLite index independently identifies `setCellLayout:` IMP 0x2F09F4 and `prepareForReuse` IMP 0x2F0A84 on the same method list (binary_id 1, list_address 0x13D37C0).

- In **`setCellLayout:`** (`0x2F09F4`), incoming layout x2 is retained as x19. At `0x2F0A38`, the routine sends **`statusViewLayoutState`** (stub `0x135CBA0`, selref `0x1ABF4B0` → string at `0x1690A91`), retaining the returned state as x21. At `0x2F0A4C..0x2F0A58`, it obtains the cell's child-view ivar via offset pointer `0x1ADD804` and places the state in x2. At `0x2F0A5C`, the child receives **`setLayoutState:`** (stub `0x13431A0`, selref `0x1AB8E30` → `0x155163A`). This resolves OX-124's unknown dispatch selector and proves the cell passes the **derived status-view layout state**, not the cell-layout wrapper, into the child.
- In **`prepareForReuse`** (`0x2F0A84`), the same child-view ivar is accessed at `0x2F0ABC..0x2F0AC8`. It obtains **`options`** (stub `0x131FF20`, selref `0x1AB0190`) and **`account`** (stub `0x12D1780`, selref `0x1A9C7A8`). It invokes **`setViewModel:options:account:`** on that child at `0x2F0AF8` (stub `0x1352060`, selref `0x1ABC9E0`), with x2 explicitly zero and subsequent arguments equal to the earlier options/account results. At `0x2F0B0C`, it sends **`setLayoutState:`** again with x2 zero, explicitly clearing the child layout state during reuse. It also clears additional local state at `0x2F0B10..0x2F0B58`; their precise meanings were not decoded.
- **OX-124 connection:** `layoutSubviews` sends `contentView.bounds` as the frame to this child view, while `setCellLayout:` hands it a separate status-view layout-state object. Neither `setCellLayout:` implementation nor the inspected `layoutSubviews` itself reads inherited `contentEdgeInsets` and applies a visible CGRect inset. Therefore margin application remains downstream/upstream and **not yet located**.
- **Limits:** No runtime inset numerical values, child header/avatar/body coordinates, or validated v12.35 behavior. OX-120 and OX-121's original standalone entries remain uncommitted; OX-122–125 cite only independently grounded facts.

**Reproduce:** `llvm-objdump -d --start-address=0x2f09f4 --stop-address=0x2f0b74 T1Twitter`; check objc stubs `0x135cba0`, `0x13431a0`, `0x131ff20`, `0x12d1780`, `0x1352060` and their rebased selrefs. Documentation only. No application, Probe, main or version changes.


## OX-126 — setLayoutState: is multiply implemented; one implementation only replaces an ivar (2026-10-22)

**Primary evidence:** User-provided official X v12.25 IPA, native `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter` and `scarlet_macho(1).sqlite`, inspected without SE. Extends OX-125; avoid attributing a selector to the wrong receiver class.

- Indexed native `objc_methods` contains **six separate `setLayoutState:` implementations** in T1Twitter: **`0x8AB24`**, **`0x2DF118`**, **`0x1408BFC`**, **`0x140A764`**, **`0x141AEBC`**, and **`0x141C808`**, in method lists `0x13A33B0`, `0x13E3830`, `0x1408BE0`, `0x140A6E8`, `0x141AEA0`, and `0x141C798`, respectively. A selector-to-IMP table alone does **not** establish which concrete receiver class implements the dispatch in OX-125.
- Native disassembly of `0x2DF118..0x2DF154`: `mov x19,x2` stores incoming state; `0x2DF130..0x2DF138` loads the ivar offset via slot **`0x1ADD704`**; `0x2DF13C` retains incoming x2; `0x2DF140` loads the previous ivar value; **`0x2DF144`** stores x19 to that ivar; final tail call at `0x2DF154` releases old value. This **particular implementation** is an object-reference setter, containing no observed child frame or margin computation.
- Rechecked OX-125 dispatch: `T1StatusCell -setCellLayout:` at `0x2F09F4` calls `statusViewLayoutState` on its incoming layout at `0x2F0A3C`; places the result in x21 at `0x2F0A48`; loads a child pointer through cell ivar offset slot `0x1ADD804` at `0x2F0A4C..0x2F0A54`; invokes **`setLayoutState:`** on that child at `0x2F0A5C`, with x2=x21. Thus the state handoff is confirmed, but this callsite does not directly encode the receiver's implementation address; dynamic ObjC dispatch must not be equated with arbitrary indexed `setLayoutState:` IMP.
- **Next static target:** identify the cell child ivar name/class and its class hierarchy; then identify the concrete `setLayoutState:` implementation or inherited setter and follow downstream `layoutSubviews`/`_t1_updateLayoutStateWithLayoutMetrics:` paths. Leave actual inset/coordinate values for SE only if they cannot be recovered from code.

**Limits:** The six indexed implementations may not be exhaustive for dynamic inheritance and XAppLibraries. Do not infer the particular child receiver is the 0x2DF118 owner. No proof yet of where `contentEdgeInsets` is applied. Documentation only, no app/Probe/main/version changes.

**Reproduce:** `SELECT imp,list_address FROM objc_methods WHERE binary_id=1 AND selector='setLayoutState:';`; `llvm-objdump -d --start-address=0x2df118 --stop-address=0x2df158 T1Twitter`; `llvm-objdump -d --start-address=0x2f09f4 --stop-address=0x2f0a84 T1Twitter`.


## OX-127 — Identify T1StatusCell child ivar as _statusView (2026-10-22)

**Source:** Original user-supplied official X v12.25 IPA, native `T1Twitter.framework/T1Twitter` disassembly plus Objective-C ivar metadata. Static-only analysis; no SE needed.

- In `-[T1StatusCell setCellLayout:]` (IMP `0x2F09F4`), code at `0x2F0A4C..0x2F0A54` loads the offset symbol at **`0x1ADD804`** and then reads the child pointer from `self + offset`. That pointer is receiver x0 for **`setLayoutState:`** call at **`0x2F0A5C`**, with the derived `statusViewLayoutState` passed in x2, matching OX-125.
- The original `T1StatusCell` native ObjC ivar metadata contains an entry at **`0x1996CC0`** whose offset pointer is **`0x1ADD804`**, whose name pointer rebases to **`0x15B0B03`**, NUL-terminated string **`_statusView`**, and whose type pointer rebases to **`0x16C36C3`**, NUL-terminated encoding **`@\"UIView<TTACoreLayoutableStatusView>\"`**. The offset slot stores numeric value **8** in this original binary.
- Thus the cell's child receiving `setLayoutState:` is concretely named **`_statusView`**, statically declared as **`UIView<TTACoreLayoutableStatusView>`**. Independently OX-124's `layoutSubviews` and `sizeThatFits:` reference this same offset symbol, tying the contentView.bounds frame assignment and intrinsicContentSize query to this ivar.
- **Important limit:** An Objective-C protocol-qualified UIView type **does not identify the actual concrete subclass created at runtime**, nor does it prove which of the multiple `setLayoutState:` IMPs from OX-126 is dispatched. Continue by tracing the constructor or `statusViewClass` selection and identifying the actual init/assignment to `_statusView`. Do not infer exact child view frames, layout insets, or v12.35 values.

**Reproduce:** `llvm-objdump -d --start-address=0x2f09f4 --stop-address=0x2f0a64 T1Twitter`; read original Mach-O native ivar record at `0x1996CC0` and `__objc_selrefs`-style dyld fixups for pointers `0x1ADD804`, `0x15B0B03`, `0x16C36C3`. No SCARLET-X production, Probe, main or version changes.


## OX-128 — Identify actual _statusView factory through statusViewClass (2026-10-22)

**Evidence:** Original user-supplied official X v12.25 IPA, native T1Twitter framework at `/tmp/T1Twitter`; direct `llvm-objdump` disassembly and original chained Objective-C selector-reference bytes. No SE needed.

- The `T1StatusCell` instance method `initWithStyle:reuseIdentifier:` has IMP **`0x2EF97C`** (method list `0x13D37C0`). After superclass initialization, at **`0x2EF9C0`** it sends **`statusViewWithFrame:`** via stub `0x135CC00` to the cell. The returned view is retained, stored into the cell's **`_statusView`** ivar (offset pointer **`0x1ADD804`**) at **`0x2EF9CC..0x2EF9D8`**, and later added to `contentView` at `0x2EFA04..0x2EFA08` using an as-yet-unresolved add-subview stub.
- The same method list has **`statusViewWithFrame:`** IMP **`0x2F099C`**. At **`0x2F09BC`** it obtains the cell class via an ObjC runtime stub; at **`0x2F09C0`** it sends **`statusViewClass`** via stub **`0x135CB40`** (native selref slot `0x1ABF498` points to original selector string `statusViewClass` at `0x1554063`). At `0x2F09C4` it allocates the class returned, then at **`0x2F09E0`** sends **`initWithFrame:isInCell:isDarkBackground:`** via stub **`0x12FFE60`** (native selref slot `0x1AA8160` points to selector C-string at `0x161A94B`). The two explicit integer flags passed at `0x2F09D8..0x2F09DC` are x2=1 (`isInCell`) and x3=0 (`isDarkBackground`); the CGRect frame is preserved in SIMD registers.
- Therefore the `_statusView` is **created through a dynamically selected class** returned by `statusViewClass`, rather than an obviously hard-coded `T1StandardStatusView` allocation in the initializer. The class-level implementation and actual subclass selected at runtime remain to be identified. This limits which `setLayoutState:` IMP can be assigned to the OX-125/126 child dispatch.
- The method/selector identities are cross-checked from original ARM64 code and Mach-O pointer bytes, not inferred from nearest disassembler symbol header.

**Reproduce:** `llvm-objdump -d --start-address=0x2ef97c --stop-address=0x2efa78 T1Twitter`; `llvm-objdump -d --start-address=0x2f099c --stop-address=0x2f09f4 T1Twitter`; ObjC stubs `0x135cb40`, `0x12ffe60` and raw selrefs `0x1abf498`, `0x1aa8160`. Next: find class/metaclass implementations of `statusViewClass` and distinguish possible subclasses.

Static v12.25 evidence only; no runtime v12.35 class selection, child coordinates, app/Probe/main/version changes.


## OX-129 — Resolve two statusViewClass implementations to standard vs focal view classes (2026-10-22)

**Primary evidence:** Unmodified official X v12.25 original IPA, extracted `T1Twitter.framework/T1Twitter`. Independently checked supplied `scarlet_macho(1).sqlite` `objc_methods` and directly disassembled actual methods and class-ref rebases. No SE needed.

- SQLite registers **two** `statusViewClass` methods in T1Twitter: `0xC008` (method list `0x1391510`) and `0x2EF7B8` (list `0x1392FC0`); both have type encoding `#16@0:8` (return a Class object).
- At **`0xC008..0xC010`**, native ARM64 uses `adrp x8,0x1AD1000; ldr x0,[x8,#0x828]; b 0x12B03D8`. Classref slot **`0x1AD1828`** rebases to class object **`0x1AED2F0`**. Class object's data ref **`0x1AED310`** → `class_ro_t 0x198A478`; name ref `0x198A490` → original C-string at **`0x1425031`**, **`T1ConversationFocalStatusView`**.
- At **`0x2EF7B8..0x2EF7C0`**, native ARM64 uses `adrp x8,0x1AD3000; ldr x0,[x8,#0xE30]; b 0x12B03D8`. Classref slot **`0x1AD3E30`** rebases to class object **`0x1AED840`**. Class object's data ref **`0x1AED860`** → `class_ro_t 0x198D7F0`; name ref `0x198D808` → C-string **`0x14254E8`**, **`T1StandardStatusView`**.
- The two method bodies thus return **different concrete classes**, both selected via `statusViewClass`. OX-128 independently establishes `T1StatusCell -statusViewWithFrame:` obtains this class from the runtime cell class, allocates and initializes it. Whether a specific runtime home-timeline cell is the standard or focal subclass requires establishing the owning metaclass/inheritance and actual object class; do not infer from a selector alone.
- Next static step: associate `statusViewClass` IMPs with metaclasses owning method lists `0x1391510` and `0x1392FC0`, then identify the concrete cell classes/constructors. Follow `T1StandardStatusView` layout-state handling after attribution. Avoid substituting v12.35 SE runtime assumptions.

**Reproduce:** `SELECT selector,imp,list_address,types FROM objc_methods WHERE binary_id=1 AND selector='statusViewClass';`; `llvm-objdump -d --start-address=0xc008 --stop-address=0xc014 T1Twitter`; `llvm-objdump -d --start-address=0x2ef7b8 --stop-address=0x2ef7c4 T1Twitter`; `llvm-objdump --macho --dyld-info T1Twitter` for rebases at `0x1AD1828,0x1AD3E30,0x1AED310,0x1AED860,0x198A490,0x198D808`.

Static reference only. No Scarlet X application, Probe, main, or version change.


## OX-130 — Attribute statusViewClass IMPs to concrete owning cell metaclasses (2026-10-22)

**Primary evidence:** Unmodified user-provided official X v12.25 IPA, original `T1Twitter.framework/T1Twitter`; binary Mach-O class_ro_t metadata and dyld chained rebases verified directly, plus previously established OX-129 returned class references. No SE required.

- `statusViewClass` IMP **`0xC008`** belongs to ObjC method list **`0x1391510`**. Dyld rebase at **`0x1939158`** identifies it as `class_ro_t` baseMethods for class-ro structure **`0x1939138`**; its name pointer at **`0x1939150`** rebases to `0x141DFB9`, original string **`T1ConversationFocalStatusViewTableViewCell`**. The class-ro flags are `0x81`, consistent with a metaclass method list. The method returns **`T1ConversationFocalStatusView`** (OX-129).
- `statusViewClass` IMP **`0x2EF7B8`** belongs to list **`0x1392FC0`**. Dyld rebase at **`0x1996C90`** identifies it as `class_ro_t` baseMethods for class-ro structure **`0x1996C70`**; its name pointer at **`0x1996C88`** rebases to **`0x1426367`**, original string **`T1StatusCell`**. Flags `0x185` include metaclass flag. The method returns **`T1StandardStatusView`** (OX-129).
- Together with OX-128, `T1StatusCell -statusViewWithFrame:` dynamically asks its actual class for `statusViewClass`; this establishes that the **`T1StatusCell` class implementation maps to `T1StandardStatusView`** while the focal cell class supplies the other class method. This is a class-level mapping, not a claim that every runtime home timeline row instantiates only these classes; subclasses might override selection.
- **Next static step:** analyze `T1StandardStatusView`'s concrete layout-state setting/layoutSubviews or layout-state application, now that its relation to `T1StatusCell` is grounded. Locate any handling of header/avatar/body child frames and `contentEdgeInsets` without guessing numeric runtime values.

**Reproduce:** Query `objc_methods` in supplied SQLite where `selector='statusViewClass'`; `llvm-objdump --macho --dyld-info T1Twitter` for rebase locations `0x1939150`, `0x1939158`, `0x1996C88`, `0x1996C90`; read strings at `0x141DFB9` and `0x1426367` directly from the unchanged binary. No production application, Probe, main or version changes.


## OX-131 — T1StandardStatusView forwards generated layout-state set to internal view set (2026-10-22)

**Primary evidence:** User-supplied official X v12.25 original `T1Twitter.framework/T1Twitter`; direct ARM64 disassembly of **`-[T1StandardStatusView _t1_updateLayoutStateWithLayoutMetrics:]`**, IMP `0x2A8A80` (owner previously verified in OX-044), and original ObjC dispatch stub + rebased selector bytes. SE not required.

- At **`0x2A8AA8..0x2A8ABC`**, method obtains `layoutStateGenerator` from the view class and retains it as x22.
- At **`0x2A8AC0..0x2A8B14`**, it loads two distinct view-owned ivars through offset slots `0x1ADD224` (x24) and **`0x1ADD228`** (x26), retrieving current model/options/account from the first and an earlier state from the second. The exact names of the ivars and `0x1314CE0` getter require independent metadata resolution.
- At **`0x2A8B18..0x2A8B30`**, x0=generator x22, x2=viewModel x23, x3=options x21, x4=account x24, x5=layoutMetrics x19, and x6=prior state x25. It invokes **`layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:`** via stub `0x1314C80`, retaining generated state as x21 at **`0x2A8B3C`**.
- Critically, at **`0x2A8B60..0x2A8B68`** it loads the second ivar into x0, sets x2=generated state x21, and calls stub **`0x13431C0`**. Original stub instructions `0x13431C0: adrp x1,0x1AB8000`; `0x13431C4: ldr x1,[x1,#0xE38]` identify selref slot **`0x1AB8E38`**; original dyld rebase targets native selector string **`0x1673748`**, reading **`setLayoutStateSet:`**.
- This proves the standard status view **hands the generated layout-state set to an internal receiver** through `setLayoutStateSet:`. It should not be conflated with **`T1StatusCell` → child `setLayoutState:`** (OX-125). The latter passes the wrapper status-view layout state to the status view; the former updates a separate internal view-set component. This suggests a layered layout propagation architecture; it does **not yet** identify the internal receiver's concrete class or child frame computations.
- Immediate next static step: resolve view ivar offset slot `0x1ADD228` through native ivar metadata to obtain the name/type of the internal receiver. Then locate `setLayoutStateSet:` IMP(s) to follow frame application. Do not invent header/body/avatar frame coordinates or v12.35 runtime values.

**Reproduce:** `llvm-objdump -d --start-address=0x2a8a80 --stop-address=0x2a8b70 T1Twitter`; `llvm-objdump -d --start-address=0x13431c0 --stop-address=0x13431d0 T1Twitter`; `llvm-objdump --macho --dyld-info T1Twitter | grep '0x1AB8E38'`; original bytes at `0x1673748` contain the NUL-terminated selector `setLayoutStateSet:`.

No Scarlet X production code, Probe, versions or main changes. Documentation only.


## OX-132 — Resolve T1StandardStatusView internal _viewSet receiver type (2026-10-22)

**Primary source:** User-supplied official X v12.25 IPA, extracted original `T1Twitter.framework/T1Twitter`. Original Mach-O class-ivar entries and the exact data dereferenced by OX-131's `-[T1StandardStatusView _t1_updateLayoutStateWithLayoutMetrics:]` (IMP `0x2A8A80`) were compared. No SE required.

- **Ivar-offset slot `0x1ADD224`** is named **`_viewModel`**: original native ObjC metadata ivar record at `0x198D2F8` rebase fields point to name string `0x15D41A8` (`_viewModel`) and type encoding string `0x16BFA9A` (`@\"T1StatusViewCombinedViewModel\"`).
- **Ivar-offset slot `0x1ADD228`** is named **`_viewSet`**: original metadata ivar record at `0x198D4B8` has a rebase to name string `0x15D420B` (`_viewSet`) and to type encoding string `0x16B75B6` (`@\"TFNComposableViewSet\"`). Its offset value is **8** in the original Mach-O.
- In OX-131's native code at `0x2A8B60..0x2A8B68`, the status view obtains the object through **ivar-offset slot `0x1ADD228`**, and sends **`setLayoutStateSet:`** (ObjC stub `0x13431C0`, selector slot `0x1AB8E38`) with newly generated state in x2. Thus its concrete *declared* receiver is a field named **`_viewSet`**, with static type **`TFNComposableViewSet`**.
- This confirms **the target of the state-set handoff** beyond OX-131's unnamed internal receiver. Caution: a declared ivar type is not evidence of the actual runtime subclass; no `TFNComposableViewSet -setLayoutStateSet:` implementation or child-view frame setters have yet been verified. Likewise `_viewModel` metadata is independently resolved; it does not establish actual home-timeline dimensions.
- Next static target: locate `TFNComposableViewSet` definition (possibly in another IPA framework) and `setLayoutStateSet:` implementation, then follow child layout application and frame setting. Avoid ungrounded SE-only numeric insets.

**Reproduce:** In original T1Twitter Mach-O read 24-byte ivar records at `0x198D2F8` and `0x198D4B8`, decode chained rebase pointer targets `0x1ADD224/0x1ADD228`, `0x15D41A8/0x15D420B`, `0x16BFA9A/0x16B75B6`; cross-check ARM64 `llvm-objdump -d --start-address=0x2a8b50 --stop-address=0x2a8b70 T1Twitter`. No app/Probe/main/version changes.


## OX-134 — Concrete child-view state and view-model forwarding in TFNComposableViewSet (2026-10-22)

**Primary source:** User-supplied unmodified official X v12.25 IPA, native `Payload/Twitter.app/Frameworks/XServiceLibraries.framework/XServiceLibraries` extracted to `/tmp/XServiceLibraries`. Independent native `llvm-objdump` disassembly of `_tfn_setupStateForView:withViewAdapter:includeViewModel:layoutState:` **IMP 0xCD7840** and `_tfn_removeView:fromHostViewWithViewAdapter:` **IMP 0xCD78F8**, method owners from original ObjC metadata as established in OX-133 (OX-133 standalone ledger addition was blocked). Each dispatch stub's selector-reference address was resolved via native Mach-O dyld chained rebases and read directly from original selector C strings.

**Resolved stub → selector pairs used by these methods:**
- `0x2F40EC0`: `__objc_selrefs 0x43CCDA8` → C-string `0x3740C9C` = **`setLayoutState:forView:`**.
- `0x2F4AE60`: `0x43CF590` → `0x374C336` = **`setViewModel:forView:`**.
- `0x2F61720`: `0x43D4FC0` → `0x3770B15` = **`view:willMoveToHostView:`**.
- `0x2F42EE0`: `0x43CD5B0` → `0x374323E` = **`setObject:atIndexedSubscript:`**.
- `0x2F5D840`: `0x43D4008` → `0x376A9D6` = **`unsetViewModelForView:`**.

**Concrete flow:**
- At `0xCD7854..0xCD7864`, the state-setup method saves x2 as x19 (view), x3 as x20 (view adapter), x4 as w22 (include-view-model flag) and x5 as w23 (layout-state flag).
- `0xCD7878` exits if view x19 is nil.
- If layout-state flag is nonzero, it looks up the view's layout state via the currently stored layout-state-set `[self+0x40]`, using adapter-associated lookup, and conditionally invokes **`setLayoutState:forView:`** on receiver x20 at **`0xCD78B4`** with x2=view x19 and x3=derived layout state x23.
- If include-view-model flag is nonzero and `[self+0x48]` is nonnull, it invokes **`setViewModel:forView:`** on x20 at **`0xCD78D4`** with x2=view x19 and x3=model in `[self+0x48]`.
- In removal helper `0xCD78F8`, a nonnull view triggers `view:willMoveToHostView:` with host argument zero at `0xCD7934`; a view-related remove action follows at `0xCD7940`; the method then clears an indexed object via `setObject:atIndexedSubscript:` and sends **`unsetViewModelForView:`** to the adapter at `0xCD7960`. This establishes a cleanup/unbinding path rather than a mere view-pointer release.
- **Scope:** These are concrete *view-adapter protocols/messages* implementing model/state association for child views. No direct `UIView setFrame:` or header/avatar/body coordinate is established by the inspected code, and exact runtime adapter classes remain unidentified. The previous OX-133 source investigation was reported conversationally but blocked at GitHub write time; this independent entry does not claim that OX-133 was committed.

**Reproduce:** `llvm-objdump -d --start-address=0xcd7840 --stop-address=0xcd7980 XServiceLibraries`; `llvm-objdump -d --start-address=0x2f40ec0 --stop-address=0x2f40ed0 XServiceLibraries` and likewise four other stubs; `llvm-objdump --macho --dyld-info XServiceLibraries | grep -iE '43CCDA8|43CF590|43D4FC0|43CD5B0|43D4008'`, then read selector bytes at target VM addresses. Static v12.25 only; SE validation deferred. No app/Probe/main/version changes.
