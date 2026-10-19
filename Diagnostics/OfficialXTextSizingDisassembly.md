# OX-011–014 — Official X v12.25 text sizing disassembly

2026-10-19。**静的解析で確認した対象関数の動作。投稿本文全体の仕様や実機一致を意味しない。**

## 一次資料・再現条件

- IPA: `com.atebits.Tweetie2_12.25_und3fined(1).ipa`（元資料は変更しない）。
- `Payload/Twitter.app/Frameworks/XServiceLibraries.framework/XServiceLibraries`
- SHA-256: `09e830331f35a7806f477cd0cbd497642461c44face5f818d39f9abd0b3040fc`
- T1Twitter SHA-256: `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`
- アドレスはunslid VM address。Capstone 5.0.7 / arm64で逆アセンブル。
- 生命令・バイト列: [OfficialXTextSizingEvidence.txt](OfficialXTextSizingEvidence.txt)。末尾が次関数へ食い込む補助レンジは、そのレンジ全体を単一関数と解釈しない。
- develop基点: `28cfb024b5abd201b1684fc9289e65bc4bdcfb9b`。

```bash
python3 -m pip install capstone==5.0.7
python3 ResearchTools/inspect_text_sizing.py --macho XServiceLibraries \
  --range 0xc9ed74 0xc9efd4 --range 0xcb1a88 0xcb1b14 \
  --range 0xcb1d98 0xcb1e28 --range 0xdd3524 0xdd374c
python3 ResearchTools/extract_class_methods.py --macho XServiceLibraries \
  --class-address 0x4422590 --expected-class TFNAttributedTextModel
python3 ResearchTools/extract_class_methods.py --macho XServiceLibraries \
  --class-address 0x442a3a8 --expected-class TFNSizeThatFitsHelper
```

## OX-011 — 未解決6アドレスの解決

外部C関数は `LC_DYSYMTAB` のindirect symbol tableと `__stubs` のreserved1/reserved2からnlistへ解決。ObjCスタブは実命令 `adrp x1; ldr x1,[x1,#offset]` の参照先が `__objc_selrefs` 内であることを検証し、そのポインタを読む。

| アドレス | 解決先 | 証拠 |
|---|---|---|
| 0x2ED5310 | `_CTFrameGetLines` | indirect symbol table |
| 0x2ED53B8 | `_CTLineGetTypographicBounds` | indirect symbol table |
| 0x2EF6AA0 | `countByEnumeratingWithState:objects:count:` | selref 0x43BA4A0 |
| 0x2EE1020 | `_tfn_buildTextPropertiesWithTrailingString` | selref 0x43B4E00 |
| 0x2EE1000 | `_tfn_buildTextPropertiesInSingleLineWithoutTrailingString` | selref 0x43B4DF8 |
| 0x2EE0FE0 | `_tfn_buildTextPropertiesInMultiLinesWithoutTrailingString` | selref 0x43B4DF0 |

セレクタ解決は動的dispatch先のクラスを単独で証明しない。ここではクラス所有メソッドの直接抽出も併用している。

## OX-012 — `_TFN_CTFrameGetSizeWithMaxLines` 全命令からの復元

範囲 `0xC9ED74..0xC9EFD4`（終端を含まない）。次の関数のシンボルは0xC9EFD4。通常returnは0xC9EFCC、0xC9EFD0はstack-check failure。

### 入力と `fitToSize:` の接続

`fitToSize:` の0xCB1AE4で直接BL。x0はself+0x48から読んだrendered attributed string、x1は `coreTextFrame` の戻り値、x2は `maxLines` の戻り値。

0xCB1AE8で返されたd0/d1をself+0x18/+0x20へ格納する。`coreTextFrame` は0xCB163Cで `_tfn_buildTextProperties` を呼び、self+0x28を返す。`_tfn_updateTextPropertiesWithRenderedAttributedString:` は0xCB24C4で `_TFN_CTFrameCreateWithAttributedStringWithMaxLines` を呼び、CTFrameをself+0x28、成功時の文字列copyをself+0x48に保存する。

### 幅

0xC9EDB8で `CTFrameGetLines(frame)`。fast enumerationで**取得した全行**を走査し、`CTLineGetTypographicBounds` の戻り値（幅）の最大値をd8へ保存する（初期値0）。0xC9EFA4の `frintp d0,d8` で正方向へ整数切り上げ。

**この関数内の幅走査にはmaxLinesによる打ち切りがない。** ただし入力CTFrame自体の行生成条件は別の関数に依存するため、「表示されない行も常に幅に含む」とアプリ全体へ一般化しない。

### 高さの対象行

- `CTFrameGetLines` のcountが0なら高さ0。
- 初期対象行kはcount−1。
- maxLinesが0でなければk=min(k,maxLines−1)（unsigned比較）。
- maxLinesが0でなく、文字列lengthが0でなく、k>0の場合、`_TFN_IsEmptyNewLine` が真の末尾行を遡る。k=0で停止する。
- `_TFN_IsEmptyNewLine`（0xCA0298..0xCA033C）はCTLineのstring rangeでattributed substringを取得し、range.length==1かつstringが定数 `"\n"` と一致するかを判定する。定数CFStringは0x40C6348、長さ1、参照先の実バイトは改行。
- **maxLines==0では、この関数の末尾改行スキップに入らない。**

### 高さの計算と精度

対象行kのoriginを `CTFrameGetLineOrigins(frame, CFRange(k,1), ...)` で取得。`CTFrameGetPath` → `CGPathIsRect(path,&rect)` → `CGRectGetMaxY(rect)` を呼び、`delta=rect.maxY−origin[k].y` を作る。

同じ行の `CTLineGetTypographicBounds` でascent/descent/leadingを取得し、以下の計算をする。

```text
base32 = fmaxnm(float32(delta), float32(ascent[k]))
height32 = float32(float64(base32) + descent[k] + 3.0)
height = float64(ceil_toward_positive_infinity_float32(height32))
width  = ceil_toward_positive_infinity_float64(max_typographic_width)
```

根拠: 0xC9EF44/4Cのdouble→float変換、0xC9EF50の `fmaxnm s0,s0,s1`、0xC9EF54のfloat→double、0xC9EF5Cのdescent加算、0xC9EF60/64の固定3.0加算、0xC9EF68のfloat変換、0xC9EFA8/ACのfloat切り上げ→double変換。

**leadingは取得するが、この関数の最終加算には直接使用しない。** CTFrameのorigin生成には間接的に影響する可能性があり、その生成仕様は未解明。先頭行ascentと末尾行descentだけを足す方式とも異なる。

**固定3.0がUI上で何を補償するかは未確認。** 呼び出し元のpaddingや行高へ勝手に加算しない。`CGPathIsRect` のBOOL戻り値はこの関数では検査しておらず、非矩形pathへの正当性を保証する解析ではない。通常の有限メトリクスを想定した復元であり、NaN/異常入力の完全な高水準モデルではない。

## OX-013 — `_tfn_buildTextProperties` 分岐

0xCB1D98..0xCB1E28。self+0x90（attributedString）がnil、またはself+0x48（構築済みrendered string）が非nilならreturn。

1. attributedTrailingString（self+0xA0）のlengthが非0、かつlineBreakMode（byte self+0x88）が **1, 2, 4** のいずれかならWithTrailingStringへ。
2. それ以外でmaxLines（self+0x98）==1ならSingleLineWithoutTrailingStringへ。
3. その他はMultiLinesWithoutTrailingStringへ。

lineBreakModeの条件は `cmp w8,#4; lsl; and #0x16; ccmp ... ls; b.eq` を追った結果。数値のUIKit列挙名への対応はここでは決めつけない。

Single/Multiとも `_tfn_updateTextPropertiesWithRenderedAttributedString:` に接続することを確認。Single経路ではparagraph styleの属性走査・Core Text paragraph style生成も見えるが、全属性変換の仕様復元は未完了。WithTrailingString経路の完全解析も残る。

## OX-014 — TFNSizeThatFitsHelper の役割

`sizeThatFits:forView:withBottomContentPadding:layout:` 0xDD3524..0xDD374C:

- viewが非nilかつlayoutフラグが真なら `_layoutSubviewsForView:atWidth:` を呼ぶ。
- class判定分岐によってcontentViewを取得する経路がある（判定対象クラス名は未解決）。
- 対象viewのsubviewsを列挙し、frameのCGRectGetMaxYの最大値（初期0）を集計する。
- 候補が最大値を更新する場合、delegateの `sizeThatFitsHelper:shouldIncludeSubview:inSizeThatFitsCalculationForView:` または `tfn_isInvisible` の否定によって採否を決める。
- 0xDD36E8で `_TFNCeilToPixel`、その結果にbottomContentPaddingを加えて高さとする。幅は入力幅を保持。viewがnilならCGSize定数をロードする別経路（定数値の解決は未実施）。

これはsubview配置に基づく集計であり、上のCTLine計測と同じ処理ではない。 `_TFNCeilToPixel` にも追加の丸め処理が見えるため、単なる整数ceilと同一視しない。scale初期化や係数の詳細は未解析。

## 抽出ツールの訂正と実行検証

旧 `extract_class_methods.py` は、間接セレクタ参照のポインタバイトを先に文字列として試し、UTF-8として通る場合に空文字や制御文字を誤受理した。0xCB12F8の `initWithAttributedString:` などで実際に再現。

修正版は今回観測したmethod-list header `0x8000000C` のみを受理し、常に間接参照を読む。空文字・制御文字を拒否する。元の報告を削除せず、この訂正を追加。修正版でモデル37件、helper7件すべてを再抽出し、該当メソッドのselector/IMP一致を確認。全44件の結果は生証拠ファイル末尾へ保存。

## T1Twitter候補の追加確認と限界

DB候補0x408300..0x408494の実コードでは `xds_content_body` を取得し、font/boldFont/lineHeight、textColor/linkTextColorをfont optionsへ設定。width/fontOptions/cachingEnabledを別optionsへ渡し、status view model相当の入力x2に `attributedTextModelForOptions:` を送って結果を返す。

**ここからTFNAttributedTextModelの上記実装へ到達することはまだ未確認。** 所有クラス、動的receiver、optionsのクラス、呼び出し元、タイムライン本文への適用条件も未確定。`xds_content_body` の名前だけでフォントや本文全体の仕様を確定しない。

## 次に追うもの

1. `_TFN_CTFrameCreateWithAttributedStringWithMaxLines`（0xC9FE48）のpath生成、行数制約、framesetter条件。
2. 単行/複数行/末尾文字列の属性変換とCore Text paragraph style。
3. T1Twitterの0x408300候補の所有クラス・呼び出し元と `attributedTextModelForOptions:` のreceiver実装。
4. actualSize→view→セル高さの接続、フォント・幅・属性を揃えた公式X実機比較。

アプリ表示コード・バージョンは変更していない。ビルド結果や実機一致の証拠は本解析には含まれない。


## OX-015 — CTFrame生成と最大行数の制御（2026-10-19追記）

同一XServiceLibrariesの `_TFN_CTFrameCreateWithAttributedStringWithMaxLines` はLC_FUNCTION_STARTSによって **0xC9FE48..0xCA00CC** と確定。入力はx0=attributed string、d0/d1=幅W/高さH、x1=maxLines、x2=truncated flagの出力ポインタ。

1. 文字列がnil、または `CTFramesetterCreateWithAttributedString` が失敗するとnilとfalseを返す。
2. `CGPointZero` と入力W/Hから `CGPathCreateWithRect` で矩形を作る（0xC9FEC0）。`CTFramesetterCreateFrame(framesetter,{0,0},path,NULL)` を呼ぶ（0xC9FEDC）。
3. maxLines==0、または初回frameの行数<=maxLinesなら、そのframeのvisibleStringRange.lengthと文字列lengthの比較をtruncated flagとする。
4. 行数>maxLinesの場合、0xC9FF18で既解析の `_TFN_CTFrameGetSizeWithMaxLines(string,frame,maxLines)` を呼び、高さhを得る。
5. **CGRect(0,0,W,H−h)** の追加pathを作る（0xC9FF1C..30）。次の属性を構成し、元の外枠pathと同じframesetterでCTFrameを再生成する（0xC9FFE0）。

```text
{ kCTFrameClippingPathsAttributeName:
    [ { kCTFramePathClippingPathAttributeName: additionalPath } ] }
```

6. この再生成経路ではtruncated flag=trueを設定する。再生成失敗時にnilになる場合でも、この経路上のflag値はtrueのまま。出力ポインタがnilなら書き込まない。

**ここで確定したのは渡される矩形と属性・分岐・再生成処理。** 任意フォントや異常寸法で最終行数が厳密にmaxLinesと一致することを実機で検証したわけではない。H−hを0へclampする命令は当関数に見当たらない。

キー/定数の解決はGOTのindirect symbol tableとchained fixupsのimportsで相互照合した。

| slot | raw pointer | imports ordinal | symbol |
|---|---|---|---|
| 0x3DF7108 | 0x80100000000000BC | 188 | _CGPointZero |
| 0x3DFA6D8 | 0x8010000000000775 | 1909 | _kCTFramePathClippingPathAttributeName |
| 0x3DFA6D0 | 0x8010000000000774 | 1908 | _kCTFrameClippingPathsAttributeName |

## OX-016 — OX-001の所有者を解決：通常本文候補としての留保を訂正

T1Twitterの0x408300は、**`+[T1StatusWithheldInCountryView _t1_attributedTextModelForStatusViewModel:width:displayType:account:]`**。

- nlist metaclass: 0x1AF3E20
- class_ro: 0x19B5C58（nameもT1StatusWithheldInCountryViewと照合）
- method list: 0x1393468、3件
- 該当entry: 0x1393488、relative IMP→0x408300
- 同じmetaclassの他メソッドは `heightForStatusViewModel:width:layoutMetrics:showsUndoButton:displayType:account:` と `_t1_innerContentInsetsForMetrics:`。

**OX-001の数値・セレクタ自体を取り消すのではなく、所有者不明を更新する。** 表示制限ビューが所有することは確定。通常の本文ビューの生成関数であるとは扱わない。他所から再利用されないことまで証明したものではない。

0x1AD18F8のbindはUIFont、0x1AD6318はTFNMutableTwitterStatusDisplayAttributedTextModelFontOptions、0x1AD6320はTFNMutableTwitterStatusDisplayAttributedTextModelOptions。先のfont/options設定の読みは維持し、画面用途の混同を避ける。

## OX-017 — 投稿データモデルからTFNAttributedTextModelへの静的接続

XAppLibraries（SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249`）のクラス/メタクラス所有メソッドを読み直した。

| owner | selector | IMP | function end (exclusive) |
|---|---|---|---|
| TFNTwitterStatus | attributedTextModelForOptions: | 0x98C588 | 0x98C600 |
| TFNTwitterStatus | _tfn_displayTextModelForOptions: | 0x98C600 | 0x98C644 |
| TFNTwitterStatus | _tfn_displayTextModel | 0x98C644 | 0x98C694 |
| TFNTwitterStatus | _tfn_displayTextModelWithheld:showFullNoteTweet: | 0x98C734 | 0x98C804 |
| TFNTwitterDisplayTextModel | attributedTextModelForOptions: | 0x96EE74 | 0x96F4D8 |
| TFNTwitterDisplayTextModel | _tfn_attributedStringForOptions: | 0x972D38 | 未解析 |

全範囲の終端はLC_FUNCTION_STARTSを使用（最後の属性生成はowner/IMPのみ確認）。

- TFNTwitterStatusの0x98C588はoptions.textOptionsでdisplay modelを選択し、その戻り値に `attributedTextModelForOptions:` を送信する。
- 選択関数0x98C600ではbit15→withheld、bit19→full note tweet、それ以外→default（bit15優先）。各フラグの数値条件を超えるUI仕様は未解明。
- defaultは0x98C65Cで `_tfn_displayTextModelWithheld:NO showFullNoteTweet:NO` を呼ぶ。
- 共通生成関数はconfiguration取得に失敗するとnil。既存モデルのconfiguration比較に一致しなければ0x98C7C4で新規alloc、0x98C7CCでinitWithConfiguration:。
- allocのclassref slot **0x6543730** はchained rebaseで **0x6578C48 `_OBJC_CLASS_$_TFNTwitterDisplayTextModel`** を指す。既存キャッシュ経路のruntimeクラスを実測したものではない。
- TFNTwitterDisplayTextModelの0x96EE74は、キャッシュを返す経路や空文字経路のほか、0x96EF14で `_tfn_attributedStringForOptions:` を呼ぶ生成経路を持つ。
- 新規生成経路の0x96F168はclassref **0x6540EB8** を読み、0x96F16Cでalloc、0x96F194で `initWithAttributedString:colorProviderView:` を送信。
- このclassrefはchained bind ordinal **12444**で **`_OBJC_CLASS_$_TFNAttributedTextModel`** に解決。これによりXServiceLibrariesで解決済みクラス定義との静的接続が得られた。
- configuration.maxLinesForOptions:/customMaxLinesForOptions:に由来するsetMaxLines:、textOptionsによるsetLineBreakMode:、末尾文字列、NOTE_TWEET_SHOW_MOREの分岐が存在。全フラグの用途・通常タイムラインで選ばれる値は未確定。

**重要な留保**: これは投稿データモデル層の経路である。通常タイムラインのどのview/cellが、どのoptions/fontOptions/widthを渡すかはまだ未確定。Objective-Cの動的置換やsubclass dispatchを実機で観測した証拠ではない。

## OX-018 — 投稿モデルの高さ取得とキャッシュ

- `-[TFNTwitterStatus attributedTextModelHeightForOptions:]`: **0x98C518..0x98C588**。上と同じdisplay-model選択を経て `attributedTextModelHeightForOptions:` を転送。
- `-[TFNTwitterDisplayTextModel attributedTextModelHeightForOptions:]`: **0x96E3C4..0x96E694**。型は **q24@0:8@16（signed 64-bit整数）**、返値はx0。CGFloat/d0ではない。
- width<=0（通常の有限値）や空文字の場合に0を返す。キャッシュ有効・条件一致の場合はcached textHeightをdouble→signed integerへ変換して返す。
- 再計測側はoptionsをmutableCopyしcachingEnabled=NOでmodelを取得し、明示maxLines/custom/configurationの条件を設定する。
- **0x96E5E4: fitToWidth: → 0x96E5EC: actualSize**。
- 返値の高さd1を0x96E5F0でfloat32へ、0x96E5F4で正方向へ整数切り上げし、0x96E618でsigned integerに変換する。cache有効なら0x96E614でcache更新補助関数0x96EAC8も呼ぶ。
- 別の生成関数内にも0x96F46CのfitToWidth:、0x96F474のactualSize、float32切り上げとcache更新がある（該当条件に入る場合のみ）。

**UITableViewの行高そのものと同一とはまだ言えない。** テキスト高さを取得するモデルAPIまで静的に追えた段階。上下余白・画像・引用・セル合成は別途追跡する。

## 今回の再現コマンドと検証

```bash
python3 ResearchTools/find_method_owners.py --macho T1Twitter --imp 0x408300
python3 ResearchTools/find_method_owners.py --macho XAppLibraries --selector attributedTextModelForOptions:
python3 ResearchTools/find_method_owners.py --macho XAppLibraries --selector attributedTextModelHeightForOptions:
python3 ResearchTools/resolve_chained_bind.py --macho XServiceLibraries --address 0x3df7108 --address 0x3dfa6d8 --address 0x3dfa6d0
python3 ResearchTools/resolve_chained_bind.py --macho XAppLibraries --address 0x6540eb8 --address 0x6543730
```

クラス/メタクラス抽出でowner名照合と実行可能IMP検証、bind/rebaseのページchain所属検証、非chainアドレスの拒否、主要6関数の境界と全命令デコードを実行済み。新ツールは今回のMach-O構成専用で、カテゴリ追加・動的method交換や他pointer形式への汎用解析ではない。

次の優先課題は **TFNTwitterDisplayTextModelの属性生成0x972D38、および実際の本文viewからのoptions/font/widthの設定と呼び出し**。固定3.0や今回の丸めをScarlet X本体へまだ適用しない。


## OX-019 — 本文ビューから計測モデルへの接続（2026-10-19追記）

XAppLibrariesの `TTAStatusBodyTextView` をclass/metaclassメタデータから解決。以下の高さAPIは **クラスメソッド**、型とIMPは生証拠へ保存。

`heightForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:richTextEnabled:trailingString:maxLines:attachmentDelegate:textKit2Enabled:cachingEnabled:`

- IMP/boundary: **0x2CCC9EC..0x2CCCBD0**（LC_FUNCTION_STARTS）。
- fontOptionsは共通補助関数 **0x2CCC518..0x2CCC9EC** で生成。
- slot0x6543798はTFNMutableTwitterStatusDisplayAttributedTextModelOptionsへrebase。textOptions、width、fontOptions、richTextEnabled、trailingString、attachmentDelegateを設定する。
- displayType **0,3,4,5,6** ではsetMaxLines:/setCachingEnabled:後に **0x2CCCB1CでviewModelへattributedTextModelHeightForOptions:**。返された整数x0をdoubleに変換し `_TFNCeilToPixel`。
- displayType **1,2** ではattributedTextModelForOptions:でモデルを取得し、**TTAStatusBodySelectableTextView** の `sizeForAttributedTextModel:width:textKit2Enabled:` に渡す（0x2CCCB68）。高さを `_TFNCeilToPixel` して返す。
- 同じ数値条件で、実際の内部rendererも **TTAStatusBodyAttributedTextView（0,3,4,5,6）** / **TTAStatusBodySelectableTextView（1,2）** に分岐する（0x2CCD570..0x2CCD5FC）。後者のinitializerはtextKit2Enabled/askGrokEnabledを受け取る。
- displayType>6の分岐は通常用途と見なさず未定義用途として留保。各数値の実際の画面名・通常タイムラインのruntime値はまだ未確認。

**訂正ではなく範囲の更新**: 前回までの「本文viewへの接続未確認」は、このTTAStatusBodyTextViewからモデルAPIを呼ぶ静的経路については解消。ただし全表示経路がCore Textへ統一される証明ではない。特にSelectable経路は別途解析が必要。

### 表示更新・幅

- `_attributedTextModelWithLayoutMetrics:` **0x2CCD91C..0x2CCDB18** は、内部rendererのselection paddingが有効なら **max(bounds.width−2×selectionPadding,0)** を有効幅としてoptions.widthへ設定する。それ以外はmax(bounds.width,0)。selectionPaddingはTFNAttributedTextViewのクラスAPIへ転送し、数値は今回未解析。
- fontOptionsは高さAPIと同じ0x2CCC518を使用。textOptions/richText/trailingString/colorProviderView/attachmentDelegate/cachingEnabledを設定し、**0x2CCDAC0でviewModelへattributedTextModelForOptions:**。
- `_updateContentIfNeeded` **0x2CCD760..0x2CCD91C** はdirty flag・layout metricsの条件を確認してmodelを構築し、**0x2CCD7F4で内部rendererへsetTextModel:**、active ranges等も更新。明示maxLinesをmodelに設定する経路とinvalidateIntrinsicContentSizeもある。
- `layoutSubviews` **0x2CCDC60..0x2CCDCC0** はsuperを呼び、content更新後にbodyTextViewFrameを得て内部rendererへsetFrame:。
- `linkTapDetectionBottomPadding` の返値6.0はタップ判定用API名に属する。文字高さへ追加する根拠にはしない。

**親セル全体の高さ・UITableViewへの登録は未確定。** direct selector stubの静的探索で当高さAPIを呼ぶ0x30C35A0（LC_FUNCTION_STARTSの包含関数0x30C31C0..0x30C37F0）を得たが、そのSwift側の所有型・用途は未解決。displayTypeは内側viewのgetterから取得され、定数0などと仮定しない。

## OX-020 — 本文fontOptionsの構築分岐

共通補助関数0x2CCC518はfont/boldFont、kerning、lineHeight、lineSpacing、emptyLineMaxHeight、各色を **TFNTwitterStatusDisplayAttributedTextModelFontOptions**（slot0x6543790→0x6578D38）へ渡す。kerningは0.0。ここでのoptionsはview表示options、次節のtextOptionsとは別引数。

**options bit33が0の場合の主な分岐**:

| displayType | 通常font / boldFont | lineHeight入力 | lineSpacing入力 | emptyLineMaxHeight入力 |
|---|---|---|---|---|
| 0（通常分岐） | xds_content_body / xds_content_bodyBold | layoutMetrics.lineHeight | 0 | 0 |
| 1,4 | xds_headline2 / xds_headline2Bold | font.lineHeight + 3 | Chirp有効0 / 無効2 | 0 |
| 2 | xds_body / xds_bodyBold | font.lineHeight + 3 | Chirp有効0 / 無効2 | floor(font.lineHeight / 3) |
| 3 | customFontOfSize:30、weight:3、scalesWithDynamicType:NO（両方同じ呼出し） | font.lineHeight | Chirp有効0 / 無効2 | 0 |
| 5 | xds_content_bodyBold / xds_content_bodyBold | layoutMetrics.lineHeight | 0 | 0 |
| 6 | xds_subtext2 / xds_subtext2Bold | font.lineHeight | 0 | 0 |

options bit33が1なら、displayType判定に先行してcontent_body/content_bodyBold・layoutMetrics.lineHeight・lineSpacing=0・emptyLineMaxHeight=0へ進む。

`_TFN_CTExtraLineHeight` はXServiceLibrariesの **0xC9FD54..0xC9FD5C** で、返値は命令上 **3.0**。これはここでlineHeightに加える値。先に解析したサイズ関数末尾の+3.0とは別の命令・別の役割であり、混同しない。

**未確認**: 各UIFontトークンの実pt、Dynamic Type実行時カテゴリ、Chirp設定実値、layoutMetrics.lineHeightの生成式。displayType0を通常タイムラインだとまだ断定しない。色の分岐は記録するが、タイポグラフィ変更の根拠にはしない。

## OX-021 — 属性付き文字列とCore Text段落設定

`-[TFNTwitterDisplayTextModel _tfn_attributedStringForOptions:]` の範囲は **0x972D38..0x9738B0**。

1. cache entryからtextを取得し、**NSMutableAttributedString**（slot0x6540E10 bind ordinal12431）をalloc。
2. **0x972E54** のinitializerへ、text/fontOptions.font、alignment（shouldBeRenderedFromRightなら2、それ以外0）、lineBreakMode=0、paragraphSpacing=0.0、fontOptions.lineHeight、fontOptions.lineSpacingを渡す。
3. fontOptions.kerningをsetKerning:へ渡す。emptyLineMaxHeight>0なら `_tfn_addEmptyLineMaxHeight:toAttributedString:` を呼ぶ（その内部効果は未解析）。
4. 色、hit-highlightのboldFont、link ranges、spoofing-prevention font、hashflags、rich-textのbold/italic、inline-media属性などの後処理が存在。全属性と全range変換の完全復元は未完了。

### initializerの正しい所有者

前回のクラス検索で空だった理由は、これらが **NSMutableAttributedStringのカテゴリ `TFSFillTemplates`** のメソッドだから。カテゴリ構造0x413D278、classref0x413D280→NSMutableAttributedString（bind ordinal6403）、method list0x2F9A9C0を確認。

- 7引数initializer **0xCA12D4..0xCA12DC** はwritingDirection=-1を追加し、8引数initializerへtail-call。
- 8引数initializer **0xCA12E4..0xCA138C** はinitWithString:後に `_setFont:alignment:lineBreakMode:paragraphSpacing:lineHeight:lineSpacing:writingDirection:` を送信。
- `_setFont:...` **0xCA1DCC..0xCA1FC8** はfontを全rangeへ設定し、CTParagraphStyleSetting 8件を構築して **0xCA1F48でCTParagraphStyleCreate**。
- **kCTParagraphStyleAttributeName**（slot0x3DFA6E0 bind ordinal1910）で全rangeへ追加する。

### 実際に構築する8設定

| specifier番号 | Core Textの設定 | 渡す値 | 値サイズ |
|---|---|---|---|
| 0 | Alignment | alignmentを変換したbyte（本文入力0→0、2→1） | 1 |
| 6 | LineBreakMode | 入力が0〜5ならそのbyte、それ以外0 | 1 |
| 9 | MinimumLineHeight | 入力lineHeight>0ならその値、そうでなければ_lineHeightForFont: | 8 |
| 14 | MaximumLineSpacing | 入力lineSpacing | 8 |
| 15 | MinimumLineSpacing | 入力lineSpacing（同じ格納先） | 8 |
| 16 | LineSpacingAdjustment | 0.0 | 8 |
| 11 | ParagraphSpacing | 入力paragraphSpacing | 8 |
| 13 | BaseWritingDirection | writingDirectionのbyte（今回のinitializerでは-1） | 1 |

定数6,9,14,15,16,11,13は **0x3081E20..0x3081E58** の実バイトから確認。設定名との対応はApple著作のiPhoneOS15.6 SDK header `CTParagraphStyle.h`（下記参照）に照合。**MaximumLineHeight（8）はこの8件に含まれない。deprecated LineSpacing（10）でもない。**

fallback `_lineHeightForFont:` **0xCA2338..0xCA2364** は **font.lineHeight + _TFN_CTExtraLineHeight() = font.lineHeight + 3.0**。

これにより最小行高と行間制約の構築は確認できたが、絵文字/fallbackを含むCTFrameの実際のbaseline・描画高さの一致は未測定。最小行高を固定行高と解釈しない。

### SDK照合元

- [Apple CTParagraphStyle.h（Theos SDK内のAppleヘッダ）](https://github.com/theos/sdks/blob/master/iPhoneOS15.6.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTParagraphStyle.h)、取得blob SHA **c3002bc14abc7400afe4efb103783ff7c276ea51**。番号定義を照合。X v12.25がこのSDKでビルドされたという意味ではない。
- [Apple CTParagraphStyleSpecifier](https://developer.apple.com/documentation/coretext/ctparagraphstylespecifier)。Web取得では一部本文がJavaScript/Markdown制約のため読めなかったので、番号の照合には上記ヘッダを使用した。

## 次に追うもの（OX-019〜021後）

1. TTAStatusBodySelectableTextViewのsizeForAttributedTextModel:width:textKit2Enabled:と描画の分岐。
2. TTAStatusBodyAttributedTextView→TFNAttributedTextViewのfit/draw/update、selectionPadding、layoutMetrics.lineHeight生成。
3. 実際の通常タイムラインcallerのdisplayType/options/width、およびセル合成・UITableViewへの反映。
4. トークン実装とDynamic Type条件。資料・同条件実機計測を根拠に比較し、アプリ本体へまだ値を適用しない。


## OX-022 — Swift側callerの本文高さ返値とレイアウト分岐（2026-10-19追加）

一次資料: XAppLibraries SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249`、unslid VM address `0x30C31C0..0x30C37F0`。LLVM `llvm-objdump -d --start-address=0x30c34b0 --stop-address=0x30c3758 XAppLibraries` で当該範囲の実命令を独立再確認。ここでは前回OX-019が解決したselector stubの対応を引き継ぐ。

- `0x30C34E8`: x22にSwiftオブジェクトのフィールドから読み出した対象body view相当のreceiverを保持。後続 `0x30C3524`/`0x30C3530` で同receiverから `displayTextOptions`/`displayType` を取得。具体的なSwift所有型・そのフィールドの型は**未確認**。
- `0x30C3580..0x30C35A0`: view model相当・options・displayTextOptions・displayType・幅(d0)・layoutMetrics相当を引数にクラス高さAPIを送る。実命令 `0x30C359C mov w7,#0` は確認できるが、多数引数のstack格納および値の意味をさらに追わずに画面名や全フラグを特定しない。
- `0x30C35A4`: 返された浮動小数の高さをv10/d10へ保存。`0x30C35C0 fcmp d10,#0`、`0x30C35C4 b.le 0x30C361C` により**高さが正かどうか**で配置が分岐する。
- 正の場合、`0x30C35DC..0x30C35F4` で対象viewへ `setFrame:`（高さとしてd10を渡す）→`setHidden:NO` を呼ぶ。負またはゼロの場合、`0x30C361C..0x30C363C` でゼロ矩形を設定し `setHidden:YES`。後続ではd10=16.0を置く。
- 正の分岐の `0x30C3608..0x30C3614` にはd10へ定数8.0と別のdouble値を加える経路がある。これは**callerの配置/後続座標計算**であり、モデルCore Textの計測高さに8ptを加えると解釈しない。`0x30C3634` の0/nonzeroフラグも表示状態の変更であって字体行高ではない。
- 後続 `0x30C36A0..0x30C3754` に別viewの `setFrame:` と `sizeThatFits:` があり、本文返値の後で周辺ビュー配置が継続することを確認。ただし、**全セル高、テーブル行高、通常タイムライン採用値は依然未確認**。

主要命令（LLVM出力の**32-bit命令語**を列記。ファイル上のリトルエンディアン4バイト列とは表示順が逆になる）:

```text
30c3524  9466ef17  bl 0x4a7f180   ; selector stub: displayTextOptions
30c3530  9466ef94  bl 0x4a7f380   ; selector stub: displayType
30c359c  52800007  mov w7, #0
30c35a0  94672718  bl 0x4a8d200   ; heightForViewModel:... stub
30c35a4  4ea01c0a  mov.16b v10, v0
30c35c0  1e602148  fcmp d10, #0.0
30c35c4  540002cd  b.le 0x30c361c
30c35e8  94683f56  bl 0x4ad3340   ; setFrame:
30c35f4  94684433  bl 0x4ad46c0   ; setHidden:
30c360c  fd435100  ldr d0, [x8,#0x6a0]
30c3610  1e692940  fadd d0,d10,d0
30c3614  1e6b284a  fadd d10,d0,d11 ; d11=8
30c3630  94683f44  bl 0x4ad3340   ; zero frame
30c363c  94684421  bl 0x4ad46c0   ; hidden YES
30c3640  1e66100a  fmov d10,#16.0
30c370c  946898b5  bl 0x4ae99e0   ; sizeThatFits:
```

**確度**: 実命令で確認したcallerレイアウト分岐。オーナーとruntime画面条件は未解明。アプリ本体に適用しない。

### OX-022記録上の表記訂正（2026-10-19）

上のLLVM列を初回記録で「命令bytes」と呼んだのは不正確。`llvm-objdump`の `52800007` は32-bit命令語で、Mach-O上の連続4バイトは `07 00 80 52`（以前のEvidence.txtの `07008052` に一致）。`0x30C35A0` の `94672718` もファイル上のバイト列は `18 27 67 94`。命令デコードと分岐先を覆す訂正ではなく、**エンディアン表記と証拠の種類の訂正**。元の一覧は残した。元XAppLibrariesのSHA-256を再照合し、該当区間をLLVMで再表示して確認した。


## OX-023 — Swift callerの直接BLを一段遡る（2026-10-19）

対象: 元IPA由来XAppLibraries、SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249`。前回OX-022の包含関数`0x30C31C0..0x30C37F0`への**直接BL**を`__TEXT,__text`（VMA `0x4000`、長さ`0x4A2F508`）の4バイト境界で実命令wordから計算して照合。AArch64 BLの26bit符号付き相対即値を4倍し、命令PCに加算。`B`も別走査。

- **直接BL caller: 1件**、`0x30C3B24 -> 0x30C31C0`。当該4-byte命令語は`0x97FFFDA7`（ファイル順bytes `A7 FD FF 97`）、llvm-objdumpも `bl 0x30c31c0` と出力した。
- 同範囲内で同ターゲットへの直接`B`は0件。この0件は**間接呼び出し、Swift vtable/witness table、objc dispatch、他Mach-Oからの呼び出しの不存在を証明しない**。
- `0x30C3B10`から始まる小関数で`0x30C3B1C`は `bl 0x4A44560`、`0x30C3B20`でその返値をx20に保存、`0x30C3B24`で解析対象関数を呼ぶ。`0x30C3B28`でx20をx0に戻し、`0x30C3B34`で`0x4A44554`へtail branch。後者のstubsは前回OX-022の解決済み`_objc_release`相当の参照と一致する。前者0x4A44560の正確なindirect symbol解決をせず用途を断定しない。
- 直前の`0x30C39E4`から別関数が始まり、後続の`0x30C3B38`から別プロローグが始まる。0x30C3B10の小関数を**Swift/ObjCの特定ownerの証拠として扱わない**。
- 0x30C3B10は無引数に見えるが、Swift implicit context registerの可能性もあり、単独の`BL`では通常タイムラインとの関係もわからない。

再現コマンド（元バイナリ）:

```bash
llvm-objdump --section-headers XAppLibraries
llvm-objdump -d --start-address=0x30c3b10 --stop-address=0x30c3b38 XAppLibraries
```

**次の分岐点**: (a) 0x30C3B10を参照するclosure/thunk descriptor, vtableなどのデータ参照を実物メタデータから確認する、(b) 0x30C31C0で読み込むSwiftフィールドoffset global 0x6789xxxの初期化元を追う、(c) UI画面での実行時displayTypeを独立確認する。実機未確認。アプリ表示コード・バージョン変更なし。


## OX-024 — 0x30C3B10の実所有者を解決：VideoRowView（2026-10-19）

元のXAppLibraries（SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249`）のMach-Oセクションを直接走査し、**0x30C3B10は`XActivityHistory.VideoRowView`の`layoutSubviews`実装**であることを確かめた。

実物からの解決手順・根拠:

1. `__objc_methlist`の相対IMP field **0x4B0F868** にsigned rel32 `0xFE5B42A8`（負）があり、`field + offset = 0x30C3B10`。これはOX-023の唯一の直接BL caller `0x30C3B24`を含む小関数。
2. 当該method listのheaderは **0x4B0F840**、`entsizeAndFlags=0x8000000C`、count=4。entryは0x4B0F848, 0x4B0F854, **0x4B0F860**, 0x4B0F86C。対象entryのselector field 0x4B0F860から `__objc_selrefs` **0x6515520** を参照し、その実ポインタのlow36 target **0x587DF20**（`__objc_methname`）の文字列は **`layoutSubviews`**。type field 0x4B0F864から `__objc_methtype` **0x5947A00** の `v16@0:8` を取得。
3. `__objc_data` の **0x65D6240** にchained rebase pointer word `0x0020000004B0F840`（low36 target 0x4B0F840）があり、このmethod listを指す。これを含むclass_ro相当の構造で **0x65D6238** のname pointer `0x001000000593FC70`（low36 target 0x593FC70）を確認。`__objc_classname`の同アドレスは **`_TtC16XActivityHistory12VideoRowView`**。Swift-mangled class名としてモジュール `XActivityHistory`、型 `VideoRowView` に対応する。
4. `llvm-objdump -d --start-address=0x30c3b10 --stop-address=0x30c3b38 XAppLibraries` で `0x30C3B24: bl 0x30C31C0` を独立照合。従って **VideoRowView.layoutSubviews → 0x30C31C0 → TTAStatusBodyTextView高さAPI** という直接静的経路が確認できた。

**解釈の訂正**: OX-022/023で「Swift側caller・所有型未解決」とした点は、この直接callerについて解消。`0x30C31C0`自体のSwift所有型・他の間接callerは未確定だが、確認できた直接呼び出しが属するのは通常タイムラインではなく**Activity HistoryのVideoRowView**。したがってこの経路を通常タイムラインの実行条件の証明として使わない。前記記録を削除せず、本節で補足・訂正する。静的所有者が分かっても公式X実機での呼び出し状況を確認したわけではない。

**次の優先順位**: TTAStatusBodyTextView高さAPIの**他の直接・間接caller**や通常のtimeline cell所有型を探す。displayType/fontOptionsの通常タイムライン入力値はなお未確定。アプリ本体変更なし。


## OX-025 — VideoRowViewから独立したT1Twitter status-cell/layoutの一次候補（2026-10-19）

OX-024のXActivityHistory.VideoRowViewを**通常タイムラインと取り違えない**ため、別バイナリT1TwitterのObjective-Cクラス定義とmethod listを調査。添付SQLite (`scarlet_macho(1).sqlite`)の`symbols`と`objc_methods`を検索し、元T1Twitter Mach-Oでclass->class_ro相当->baseMethods参照（low36 target）と対象IMPのARM64命令を照合。

- `_OBJC_CLASS_$_T1StatusCell`: **0x1AEF370**、class data low36 target **0x1996E28**、baseMethods low36 target **0x13D37C0**。SQLiteの同listには61件。代表: `statusViewWithFrame:` 0x2F099C、`layoutSubviews` **0x2F0B74**、`sizeThatFits:` **0x2F0BE4**、`setCellLayout:` 0x2F09F4（addressはdecimal IMP値をhexへ変換したもの）。
- `_OBJC_CLASS_$_T1StatusCellLayout`: **0x1AEF348**、ro target **0x1996F28**、baseMethods **0x13D3AA8**。SQLiteに5件（`statusOptions`, `setStatusOptions:`, `statusViewLayoutState`, `setStatusViewLayoutState:`, `.cxx_destruct`）。
- `_OBJC_CLASS_$_T1StandardStatusViewLayoutStateGenerator`: **0x1AED818**、ro target **0x198DAF0**、baseMethods **0x13D2F00**。SQLiteのselector `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` はIMP **0x2AE63C**。LLVMで`0x2AE63C`に関数プロローグがあり、複数の引数レジスタを退避して呼び出しを行うことを確認。
- `_OBJC_CLASS_$_T1StandardStatusViewLayoutState`: **0x1AED8B8**、ro target **0x198D9D8**、baseMethods **0x13D2E50**。SQLiteには`verticalLayout`, `size`, `avatarFrame`の各getter/setterがあり、セル全体の計測を追う探索入口として有望だが、**役割はselector名からの仮説**。
- LLVMで`0x2F0B74`にスタックプロローグ、`0x2F0BE4`にivar load/tail branchを確認。ただし`sizeThatFits:`の転送先の**受信クラスと最終高さ式は未解決**。

**確実な事実**は上記class/list/selector/IMPと実命令存在。**まだ立証していない**のは、これらが通常タイムラインの実際の選択経路であること、`TTAStatusBodyTextView`への直接/間接呼び出し、具体的なdisplayType・fontOptions・本文の最終行高。別Mach-Oでの動的dispatchや過去のVideoRowView経路を自動的に接続しない。

次は`T1StandardStatusViewLayoutStateGenerator`の`0x2AE63C`でメッセージ送信先をstub/selectorまで解決し、`T1StatusCell`の`setCellLayout:`・`layoutSubviews`へのデータ接続と、通常タイムラインでの利用証拠を並行追跡する。


## OX-026 — T1StandardStatusViewLayoutStateGeneratorの入口を実命令で検証（2026-10-19）

入力は元IPAのT1Twitter。SQLite `scarlet_macho(1).sqlite` に `binary_id=1, selector=layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:, imp=2811452 (0x2AE63C), types=@56@0:8@16Q24@32@40@48` を再確認。元Mach-Oの `llvm-objdump -d --start-address=0x2ae63c --stop-address=0x2ae9a0 T1Twitter` でコードを独立確認。

関数入口の確認事項（指定PCはunslid VM address）:

- `0x2AE63C sub sp,sp,#0x130`、`0x2AE640..668` に保存レジスタ/フレーム準備。これはSQLiteのIMPアドレスが実際の関数入口であることと整合する。
- `0x2AE66C mov x26,x6`, `0x2AE670 mov x19,x5`, `0x2AE674 mov x25,x4`, `0x2AE678 mov x21,x3`, `0x2AE67C mov x23,x2`, `0x2AE680 mov x20,x0`。引数を退避し後続で参照する。selectorの引数名だけで受信クラスやオブジェクト構造を仮定しない。
- `0x2AE6C4..0x2AE6D4` はx2=x23, x3=x21, x4=x25, x5=0を設定して `0x1303880` にBL。返値は `0x2AE6D8` にx22へ保存。呼び先のselectorとownerは**まだ未解決**。
- `0x2AE6DC..0x2AE6E4` は別の入力に `0x13104E0` を呼び、その返値w0について `cbz` による条件分岐。分岐によって `0x2AE6E8` で受け取る候補または `0x2AE6F8..70C` で生成する候補をx21に置き、`0x2AE710..` の共通経路へ進む。
- `0x2AE710..0x2AE754` に複数の間接Objective-C stub相当のBLと返値を中間レジスタへ保存する経路。**stub/selref解決前に具体的なレイアウトクラスを推定しない**。
- `0x2AE864..` では一つの呼出し結果x0を1および2と比較して分岐し、`0x2AE880` では返り値のbit0を検査する。**この値をTTAStatusBodyTextViewのdisplayTypeと同一視しない**。

**現時点の限界**: T1Twitter内のgeneratorに入力選択・条件分岐・複数のメッセージ送信があることまでは実命令で確認したが、呼び先stubのselector・receiver所有者・TTAStatusBodyTextViewとの連結・最終セル高の式は未解決。LLVMの表示する`_T1ShouldAttachUnifiedCardForViewModel` は近傍のシンボル見出しであり、このIMPの関数名を証明しない。OX-025で想定したgenerator→layout state→cellの関係は依然探索仮説。

**次に必要な操作**: `0x1303880`, `0x12E87A0`, `0x1370B80`, `0x13104E0`, `0x132A260` 等についてT1Twitterの`__objc_stubs`と`__objc_selrefs`からselectorを解決し、receiverを追ってから、返値の型とcellへの受け渡しを評価する。公式X実機未確認、アプリ本体は変更していない。

### OX-026追加検証 — Objective-C stub / selectorの実バイナリ解決

同じ元T1Twitter（SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`）について、`__TEXT,__objc_stubs`先頭の`ADRP x1 + LDR x1`から`__DATA,__objc_selrefs`のslotを導き、slotのchained pointerのlow36 targetを`__objc_methname`内の文字列として検証した。Mach-O `LC_SEGMENT_64` のVM/file mapを使用し、ファイルオフセットとVMアドレスを分離。前節の未解決呼び先を以下のように更新する。

| BL target | selref slot | 実物で解決したselector |
|---|---|---|
| 0x1303880 | 0x1AA8FE8 | `initWithStatusViewModel:options:account:scribeContext:` |
| 0x13104E0 | 0x1AAC300 | `isStatusViewLayoutStateGeneratorCachedViewAdapterSetEnabled` |
| 0x12E87A0 | 0x1AA23B0 | `customizeLayoutMetrics:forViewModel:viewAdapterSet:` |
| 0x1370B80 | 0x1AC44A8 | `viewIdentifiersWithValidLayoutStateInSet:forViewModel:layoutMetrics:` |
| 0x1305720 | 0x1AA9790 | `initWithViewModel:layoutMetrics:` |
| 0x1323D80 | 0x1AB1128 | `populateLayoutStateSet:withValidViewIdentifiers:inPreviousLayoutState:` |
| 0x132A260 | 0x1AB2A60 | `promotedBadgePlacement` |
| 0x1354640 | 0x1ABD358 | `shouldDisplayAsCompactPromotedTweet` |

これにより、`0x2AE6C4..0x2AE6D8` は `initWithStatusViewModel:options:account:scribeContext:` を送った返り値をx22へ保持する経路、`0x2AE6DC` はキャッシュされたview adapter set利用フラグを判定する経路、`0x2AE718..0x2AE730` は `customizeLayoutMetrics:forViewModel:viewAdapterSet:` の返り値を次段へ渡す経路、`0x2AE740..0x2AE758` は `viewIdentifiersWithValidLayoutStateInSet:forViewModel:layoutMetrics:` へ渡す経路であることを**selectorレベル**で裏付けた。

`0x2AE864..0x2AE884` の数値1/2の比較対象は `promotedBadgePlacement` 由来であり、**OX-019の本文displayType=1/2ではない**。ここは混同を避けるため明示。 `0x1354640`のbit0検査は `shouldDisplayAsCompactPromotedTweet` の返値であり、同様に本文表示タイプとは区別する。

ただし、selectorだけでは動的receiverの実クラスや通常タイムライン採用の証明にはならない。今回の確認は**generator内部のlayout metrics / adapter set / cache利用経路**に限定され、本文の計測値の取得箇所とセル最終高さは未追跡。新しいアプリUI変更なし。


## OX-027 — LayoutStateGenerator後半にある座標計算候補の切り分け（2026-10-19）

一次資料: 添付の公式X v12.25 T1Twitter Mach-O、SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`（今回再照合）。対象はOX-025/026で所有者を解決した `-[T1StandardStatusViewLayoutStateGenerator layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:]` の内部、**0x2AED80..0x2AEE30**。通常タイムラインのruntime採用は未立証。

```text
2aed94  943fea40  bl     0x12a9694
2aed98  4ea01c0a  mov.16b v10, v0
2aed9c  4ea11c2b  mov.16b v11, v1
2aeda0  4ea21c4c  mov.16b v12, v2
2aeda4  4ea31c6d  mov.16b v13, v3
2aedb0  9441bfb4  bl     0x131ec80
2aedc0  9440ae70  bl     0x12da780
2aedc4  6d010fe2  stp    d2, d3, [sp,#0x10]
2aedc8  6d0007e0  stp    d0, d1, [sp]
2aede0  943feaf3  bl     0x12a99ac
2aede4  1e682808  fadd   d8,d0,d8
2aedf0  9441bfa4  bl     0x131ec80
2aee00  94411350  bl     0x12f3b40
2aee04  1e61390b  fsub   d11,d8,d1
2aee20  1e6e6968  fmaxnm d8,d11,d14
2aee24  aa1603e0  mov    x0,x22
2aee28  9440a1be  bl     0x12d7520
2aee2c  f1001c1f  cmp    x0,#7
2aee30  54000fe1  b.ne   0x2af02c
```

`llvm-objdump -d --start-address=0x2aed80 --stop-address=0x2aee80 T1Twitter` で実命令を照合。左の8桁はLLVMが表示する32bit命令語で、file-order bytesではない。**確定できる事実**: 0x2AEDE0の呼び出し後、返りd0を既存d8へ加算し、0x2AEE00の呼び出し後にd1を減算し、`fmaxnm`でd14との下限候補を計算したのち、別条件に分岐する。

**未解決**: 0x12A9694 / 0x131EC80 / 0x12DA780 / 0x12A99AC / 0x12F3B40 / 0x12D7520 のselector、実際のreceiver、d8/d14の初期値の意味、ここでの座標が本文なのか画像/カード等なのか、最終的なlayout stateのsizeへの格納。この段階では**本文高さをセル高へ加算していると断定できない**。近傍シンボル表示 `_T1ShouldAttachUnifiedCardForViewModel` は関数ownerの根拠にしない。

**次の検証**: 上記stubをXServiceではなく**T1Twitter自身の**selrefsから解決し、0x131EC80に渡す`w2=5`の意味と、返り値の型、d8への取り込みを逆方向追跡する。次に実際のstate.size setterへの到達とT1StatusCellへの受け渡しを調べる。アプリ本体・バージョン・mainは変更しない。


## OX-028 — OX-027の座標算術はnon-text baseline spacingとindex-5 view.frame（2026-10-19）

元T1Twitter（SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`）を再調査。OX-027の未解決値を、実Mach-O `__objc_stubs` のADRP/LDR→`__objc_selrefs`と `llvm-objdump --macho --dyld-info` の `__DATA_CONST,__got` bindで解決。

| caller BL | stub/GOT or selref | 解決名 | 出典 |
|---|---|---|---|
| `0x2AEDB0` | ObjC stub `0x131EC80`, selref `0x1AAFCE8` | `objectAtIndexedSubscript:` | slot raw target `0x16452D2` |
| `0x2AEDE0` | C stub `0x12A99AC`, GOT `0x18682C0` | `_TFNVerticalSpacingForBaselineEdgeInsets` | chained bind word `0x8010000000002561`; dylib XServiceLibraries |
| `0x2AEE00` | ObjC stub `0x12F3B40`, selref `0x1AA5098` | `frame` | slot raw target `0x1606754` |
| `0x2AED94` | C stub `0x12A9694`, GOT `0x1868000` | `_TFNBaselineEdgeInsetsForNonTextWithSimulatedFont` | chained bind word `0x8010000000002509`; dylib XServiceLibraries |

訂正: 第1行のcallsiteは**0x2AEDB0**（前段に `mov w2,#5`）。同selectorは**0x2AEDF0**からも呼ばれ、返値を`x21`に保持する。二度ともx0=x27/w2=5の入力で`objectAtIndexedSubscript:` を呼ぶ。続く`0x12B0444`は返却オブジェクトに対するretain相当のスタブだが、間接symbolの独立解決前に対象collectionのクラスは断定しない。**index 5は配列要素の選択であり、本文displayType 5とは無関係**。

`0x2AEE00 frame` は`x21`に対する呼出しで、直後の`0x2AEE04 fsub d11,d8,d1`で**CGRect.frame結果の第2浮動小数成分d1（origin.yに相当）**を減算。もう一方の`0x2AEDE0`は非テキスト用baseline edge insetsからの縦間隔を返す補助関数にbindされる。従ってOX-027の計算を**投稿本文のCore Text高さ合成だと読む根拠はなく、非テキスト要素のbaseline spacingと別viewのframe座標のレイアウト演算**として区別できる。

**範囲の留保**: `_TFNVerticalSpacingForBaselineEdgeInsets`の引数とd0返値の正確な算式、index 5の実際のview種類、d8/d14の意味、最終state.sizeへの反映は未解決。外部bind名だけではそれらは確定しない。旧OX-027を残して今回解決分を追記。通常タイムラインのruntime実行やセル高式は未証明。アプリ本体変更なし。

再現:
```sh
llvm-objdump -d --start-address=0x2aed80 --stop-address=0x2aee45 T1Twitter
llvm-objdump -d --start-address=0x131ec80 --stop-address=0x131ec94 T1Twitter
llvm-objdump -d --start-address=0x12f3b40 --stop-address=0x12f3b54 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep -Ei '0x1868000|0x18682C0'
```

## OX-029 — T1StandardStatusBodyViewAdapterの所有者とレイアウト入口（2026-10-19）

一次資料: T1Twitter SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`（本ターン再計算一致）。`scarlet_macho(1).sqlite`の参照に加え、Mach-Oの`_OBJC_CLASS_$_T1StandardStatusBodyViewAdapter`とrelative method listを**直接**読み、セレクタ・型・IMPを照合した。nlist class=**0x1AF28B8** → class_ro（low36）=**0x19AD578**、class name=`T1StandardStatusBodyViewAdapter`、baseMethods=**0x13D15F0**、list header=`0x8000000C`、**36件**（instance methods）。

関係が深いowner付きメソッド（unslid VM address）:

| selector | IMP | Objective-C type |
|---|---|---|
| `initWithViewIdentifier:displayType:displayLocation:` | `0x3BA434` | `@40@0:8q16Q24Q32` |
| `shouldBeVisibleForViewModel:` | `0x3BA520` | `B24@0:8@16` |
| `initializeView` | `0x3BA7C0` | `@16@0:8` |
| `setViewModel:forView:` | `0x3BA890` | `v32@0:8@16@24` |
| `layoutStateForViewModel:layoutMetrics:` | `0x3BAE90` | `@32@0:8@16@24` |
| `isLayoutState:validForViewModel:layoutMetrics:` | `0x3BB4CC` | `B40@0:8@16@24@32` |
| `_t1_displayTextOptionsForViewModel:` | `0x3BB778` | `Q24@0:8@16` |
| `displayType` | `0x3BBED4` | `Q16@0:8` |
| `displayLocation` | `0x3BBEE4` | `Q16@0:8` |

このクラスは `bodyTextView:didTapActiveTextRange:` (0x3BBA30), `bodyTextViewDidTapTruncationToken:` (0x3BBB0C) 等の本文操作delegate selectorも保持する。従って単なる汎用セルより**本文処理に直接関係する所有クラス候補**として大きく前進した。ただし実際の通常タイムラインでこのadapterが選ばれたruntime観測は未実施。

`llvm-objdump -d`の実命令から:
- `initializeView` (0x3BA7C0): classref slot `0x1AD5FC8`をロードしてalloc相当stub `0x12B02F4`を呼び、instance ivarから別入力を読み、`0x12FF2A0`へ送り、終端で`0x12B033C`へtail branch。**classrefのbind解決前に生成されるUIViewの具体的クラスは断定しない**。
- `layoutStateForViewModel:layoutMetrics:` (0x3BAE90): x2(viewModel),x3(layoutMetrics)を保持し、`0x3BAF10`でnil分岐。非nil経路 `0x3BAF28..0x3BAF34`には、保持したオブジェクトのoffset `0x10`の関数ポインタを`BLR x8`で呼ぶ処理がある。返り値の浮動小数レジスタ v0/v1をv8/v9へ保存し、`0x3BAF50`でd8をゼロと比較、必要なら別の補助経路を実行する。`0x3BB008`にはbit19の分岐があるが、意味と通常の値は未解決。

**重要**: 本解析で`T1StandardStatusBodyViewAdapter`というownerと、本文モデル/表示オプションを結ぶ重要な入口を見つけた。ただし、`layoutStateForViewModel:`が具体的にどのTTAStatusBodyTextView高さAPIへ行くか、offset+0x10のcallbackの所有者・意味、stateの最終高さ、通常タイムラインのdisplayTypeはまだ未確定。OX-024のVideoRowViewのレイアウト式は転用しない。元バイナリ・アプリ本体は未変更。

再現:
```sh
llvm-objdump --macho --syms T1Twitter | grep 'OBJC_CLASS_\\$_T1StandardStatusBodyViewAdapter'
llvm-objdump -d --start-address=0x3bae90 --stop-address=0x3bb1a0 T1Twitter
llvm-objdump -d --start-address=0x3ba7c0 --stop-address=0x3ba890 T1Twitter
```


## OX-030 — standard body adapterの生成ビューと最大サイズblockを解決（2026-10-19）

対象T1Twitter SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`、XAppLibraries SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249` を本ターン再計算一致。T1Twitterの実Mach-Oの `__objc_stubs` 内`ADRP x1`＋`LDR x1`から`__objc_selrefs`を読み、low36 targetが`__objc_methname`の文字列になることを確認。`llvm-objdump --macho --dyld-info T1Twitter`でclassrefのbindも照合。

**1. initializeView = 実際にTTAStatusBodyTextViewを生成する接続**

- `0x3BA7D0..0x3BA7D8` はclassref slot `0x1AD5FC8`を読んで`0x12B02F4`（alloc系stub）へ送る。slotはchained bind `_OBJC_CLASS_$_TTAStatusBodyTextView`、dylib `XAppLibraries` と解決。
- `0x3BA7E8` は `0x12FF2A0` へBL。このObjC stubのselref slot `0x1AA7E70`→name `initWithDisplayType:`。引数x2はadapterのivarからロード（`0x3BA7E0..E4`）された値。`0x3BA7F4` のtail branchは別のretain/autorelease系stubだが、未解決のため正確な意味は断定しない。
- 従って **T1StandardStatusBodyViewAdapter.initializeView → TTAStatusBodyTextView alloc/initWithDisplayType:** は静的に確認。通常タイムラインのruntime displayType数値とこのadapterの採用条件は別途未確認。

**2. layoutStateForViewModel:layoutMetrics:の間接呼出しはmaximumSizeBlock**

- `0x3BAF00`（receiver x24=adapter）からObjC stub `0x1319BA0` を呼び、戻りオブジェクトをx23に保持。`0x1319BA0`のselref slot `0x1AAE8B0`→ `maximumSizeBlock`。
- x23がnon-nilの場合、再度 `maximumSizeBlock` を取得し、`0x3BAF28 ldr x8,[x0,#0x10]`、`0x3BAF2C mov x1,x19`（viewModel）、`0x3BAF30 mov x2,x20`（layoutMetrics）、`0x3BAF34 blr x8` でblockのinvoke pointerを実行。これは**任意の不明なメソッドポインタではなく、adapterのmaximumSizeBlock経由の間接呼出し**である。block invokeの具体的実装アドレス・設定元は未追跡。
- 戻りのv0/v1をv8/v9に保存し、`0x3BAF50 fcmp d8,#0`。幅の成分が0の経路では、`0x12DB600` selector `bodyWidth`（selref `0x1A9EF48`）をx20=layoutMetricsへ送信し、返るv0をv8へ保存（`0x3BAF58..60`）。このため幅0時にはlayoutMetrics.bodyWidthを採用するフォールバックがあると読める。
- 同関数`0x3BAEDC`のstub `0x12BB1C0`はselref slot `0x1A96E38`→ `_t1_convertToAutoTranslatedViewModelIfNeeded:`。自動翻訳用モデル変換分岐があるが、返りmodelの実型と通常タイムラインでの採用条件は未確認。
- `0x3BB074..0x3BB080`の条件付き-8.0は別フラグによって幅候補d8を調整。本文高さの一律-8ptとは解釈しない。

**現時点の結論**: OX-029の不明なclassref / 間接callbackは上記の範囲で解消し、body adapter→TTAStatusBodyTextView生成の**実接続**も確認した。未解決は (a) maximumSizeBlockの設定元とblock invoke実装/戻りCGSizeの利用全体、(b) このadapterが通常タイムラインで選ばれる実条件、(c) adapterの`displayType`/`displayTextOptions`とTTA height APIへの値の伝播、(d) 最終layout state.size/セル高への合成。静的証拠であり、公式X実機の表示一致を意味しない。アプリ本体/main/バージョンは変更しない。

再現:
```sh
llvm-objdump --macho --dyld-info T1Twitter | grep '0x1AD5FC8'
llvm-objdump -d --start-address=0x3ba7c0 --stop-address=0x3ba7f8 T1Twitter
llvm-objdump -d --start-address=0x3bae90 --stop-address=0x3bb0b0 T1Twitter
llvm-objdump -d --start-address=0x1319ba0 --stop-address=0x1319bb4 T1Twitter
```


## OX-031 — Body adapterのCGSize合成とnil block fallback（2026-10-19）

一次資料: T1Twitter v12.25 SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`、XAppLibraries SHA-256 `ce10ca22abc997bfc3eb7732be33c198175994e24a421219cf0808c6e7882249`。既知の`-[T1StandardStatusBodyViewAdapter layoutStateForViewModel:layoutMetrics:]`（0x3BAE90）の0x3BAF00..0x3BB370を、元Mach-O `llvm-objdump`で再デコード。

**間接maximumSizeBlockとフォールバック**
- `0x3BAF10 cbz x0,0x3BB01C`: `maximumSizeBlock`がnilなら、`0x3BB01C`でlayoutMetricsに`bodyWidth`を送り、`0x3BB024 mov v8,v0`、`0x3BB028 fmov d9,xzr`で**サイズ候補 (width=bodyWidth,height=0)** とする。
- blockがある場合、`0x3BAF34 blr x8`の結果（v0/v1）をv8/v9へ保存。width=d8が0のとき`0x3BAF58`のbodyWidthを採る。ただしblockのinvoke実装/割当元は未確定。
- 条件付き`0x3BB074..0x3BB080`はd8に-8を加えた幅候補と元幅を、フラグbit0で`fcsel`する。**高さではない**。

**サイズ合成（0x3BB270以降）**
- `0x3BB270 fcmp d8,#0`; `0x3BB274 b.le 0x3BB2C4`; `0x3BB278 fcmp d9,#0`; `0x3BB27C b.le 0x3BB2C4`。幅または高さの候補が0以下なら`0x3BB2C4`へ分岐する。
- 両方正の場合:
```text
0x3BB280 fadd d1,d10,d10   # 2*d10
0x3BB284 fadd d0,d1,d8     # W = d8 + 2*d10
0x3BB288 fadd d1,d11,d1
0x3BB28C fadd d1,d1,d9     # H = d9 + d11 + 2*d10
0x3BB290 BL 0x134D200     # CGFloatペアを引数に渡す呼出し
0x3BB298 fneg d0,d10
0x3BB29C fsub d2,d0,d11    # -(d10+d11)
0x3BB2AC BL 0x13354E0
```
- この分岐で成立する算術恒等式は **W=d8+2*d10, H=d9+d11+2*d10**。ただし、d10/d11が意味する実際のpadding・insetsは**selector/データフロー解決まで未確定**。呼出し先のクラス/引数の用途も現時点で断定しない。
- いずれかが0以下なら`0x3BB2C4`でメモリからd0/d1をロードし`0x134D200`へ渡す、異なるサイズ設定経路。読み込む定数の具体的CGSizeは現段階では未解決。
- `0x3BB2B0..0x3BB2F8`の後段はadapterのgetter戻り値を1/2と比較して追加分岐。前段で既に`displayType` getterを確認したとしても、**このgetterのselectorは実際のstub/selrefを再検証するまでdisplayTypeと断定しない**。
- `0x3BB334..0x3BB36C`ではXAppLibrariesにbindされた`TTAStatusBodyTextView`のclassref slot `0x1AD5FC8`を再びロードし、`0x12F3100`へBLして別のオブジェクトを取得し、後段で返値を保持する。これは**body viewクラス参照を含むサイズ/状態構築箇所**だが、selectorや返りオブジェクト型を解決するまでheight APIと混同しない。

**更新した未解決条件**: (a) maximumSizeBlock設定元/実体、(b) d10/d11の生成元と意味、(c) `0x134D200`/`0x13354E0`/`0x12F3100`を含むselector、(d) 返されるstateの具体的サイズ格納先、(e) 通常タイムライン採用とruntime displayType。公式X実機未確認。アプリ本体・main・バージョン未変更。

再現コマンド:
```bash
llvm-objdump -d --start-address=0x3bae90 --stop-address=0x3bb4cc T1Twitter
```


## OX-032 — 本文高さAPI直結、selectionPaddingとlinkTapDetectionBottomPaddingの同定（2026-10-19）

一次資料: T1Twitter X v12.25 `/mnt/data/T1Twitter`。前回OX-031で未解決だった`-[T1StandardStatusBodyViewAdapter layoutStateForViewModel:layoutMetrics:]` (0x3BAE90) のselectorを、元Mach-Oの`__objc_stubs`にあるADRP/LDRのselref slotを直接読んで再確認。元アプリ・ライブラリ・main未変更。

**本文高さへの直接接続**
- `0x3BB130..0x3BB158`は`TTAStatusBodyTextView` classref (0x1AD5FC8) をreceiver (x0) にして、viewModel (x2=x22)、`options`の値 (x3=x23)、layoutMetrics (x4=x20)、adapter `displayType` (x5)、幅候補 (d0=d8)、追加の引数 (x6=x20復元値、x7=x26、stack上にも値) を設定し、`0x3BB158 bl 0x12F8400`を実行。
- `0x12F8400` selref slot `0x1AA62C8` → **`heightForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:richTextEnabled:trailingString:maxLines:attachmentDelegate:textKit2Enabled:cachingEnabled:`**。これはOX-019で実装解析済みの`TTAStatusBodyTextView`高さAPIと同じselectorであり、**standard body adapter→公式本文height APIの静的直接接続を確認**。引数の完全な対応と実際のdisplayType数値は今後の追跡課題。
- `0x3BB15C fminnm d1,d9,d0`、`0x3BB160 fcmp d9,#0`、`0x3BB164 fcsel d9,d1,d0,gt`。ここから `heightCandidate = d9>0 ? minNum(d9, returnedHeight) : returnedHeight`（NaN取扱いはfminnm）と読める。maximumSizeBlockの高さ候補は、正なら実測API高さの上限として働き、0ならAPI高さを使う。

**OX-031 d10/d11の取得元を解決**
- `0x3BB0B8 bl 0x131FF20` のselector = `options` (selref `0x1AB0190`)。戻りbit33を`0x3BB0C8 tbnz x0,#0x21`で検査。bit33が有効ならd10,d11は初期値0のまま。
- bit33が無効の場合のみ、TTAStatusBodyTextView classref slot `0x1AD5FC8`をreceiverに:
  - `0x3BB0D0 bl 0x1333C60` selector `selectionPadding` (selref `0x1AB50E0`) → d10
  - `0x3BB0DC bl 0x13156C0` selector `linkTapDetectionBottomPadding` (selref `0x1AAD778`) → d11
- よって **bit33がoff**、本文幅d8・採用済み高さd9が正の経路では、`0x3BB280..0x3BB28C`の合成式は **W = d8 + 2*selectionPadding, H = d9 + linkTapDetectionBottomPadding + 2*selectionPadding**。**bit33がonでは両paddingは0**。値の具体的pt数はこの調査では未解決。d9は前述のheight API結果を最大高さ候補でcapした値。
- `0x3BB294 bl 0x134D200` selector `setSize:` (selref `0x1ABB648`) 。`0x3BB2AC bl 0x13354E0` selector `setAdditionalEdgeInsets:` (selref `0x1AB5700`)、値は`(-d10,-d10,-d10-d11,-d10)`（d0,d1,d2,d3）。これはsizeへ加えた計測用寸法を別途negative edge insetsとして状態に登録する処理。順序はarm64構造体引数からの推論を含むため、UIEdgeInsetsのtop/left/bottom/rightへの対応を厳密に断定する前にメソッド型エンコーディング確認が必要。
- `0x3BB2C4`以下のサイズ非正フォールバックでも、`setSize:`を呼ぶ。
- `0x3BB2B4/0x3BB2DC/0x3BB2E8`はadapterの`displayType` selector (stub `0x12ED280`, selref `0x1AA3668`) を取得し1/2と比較。`0x3BB32C`は`setValidForFocalTweetIncompleteQuotedStatus:` selector (stub `0x1351760`, selref `0x1ABC7A0`)。ここはruntime値が未確認。
- `0x3BB36C bl 0x12F3100` selector `fontForViewModel:options:displayTextOptions:displayType:width:layoutMetrics:` (selref `0x1AA4E08`) 、receiverは再度 `TTAStatusBodyTextView` classref。**同じadapterで高さAPIと表示フォントAPIの両方を呼ぶ**と確認。

**重要な制限**: これでOX-030/031の未解決selectorが複数実証でき、adapter→height API→サイズ状態`setSize:`というコード上の連続性を確認した。ただしadapter採用の実際のタイムライン条件、実測displayType、全引数x6/x7とstackの正確な種類、端末フォントpt値、`maximumSizeBlock`自体の設定元は未確認。ビット33の意味も推測で付けない。正規Xの端末実機観測はなし。Scarlet Xには未適用。

再現用:
```bash
llvm-objdump -d --start-address=0x3bb0b4 --stop-address=0x3bb390 T1Twitter
llvm-objdump -d --start-address=0x12f8400 --stop-address=0x12f8414 T1Twitter
llvm-objdump -d --start-address=0x1333c60 --stop-address=0x1333c74 T1Twitter
llvm-objdump -d --start-address=0x13156c0 --stop-address=0x13156d4 T1Twitter
```


## OX-033 — 本文paddingの静的戻り値追跡（2026-10-19）

一次資料: 手元のX v12.25 XAppLibraries Mach-O。OX-032で解決したTTAStatusBodyTextViewの二つのclass methodを再度実命令で検査（`llvm-objdump -d --start-address=0x2cccbc0 --stop-address=0x2cccbf8 XAppLibraries`）。SQLiteの`objc_methods`には同クラスmethods list `0x4B27B30`上の`selectionPadding` IMP `0x2CCCBD0`、`linkTapDetectionBottomPadding` IMP `0x2CCCBDC`がある。**実命令でメソッド開始位置と処理を再確認した**。

- `0x2CCCBDC fmov d0,#6.00000000`, `0x2CCCBE0 ret`。**TTAStatusBodyTextView.linkTapDetectionBottomPadding は定数6.0（CGFloat/double）を返す**。
- `0x2CCCBD0 adrp x8,...; 0x2CCCBD4 ldr x0,[x8,#0xD98]; 0x2CCCBD8 b 0x4AC9820`。対象classref slot `0x6540D98`を`llvm-objdump --macho --dyld-info`で検査し、XServiceLibraries `_OBJC_CLASS_$_TFNAttributedTextView`へbindと確認。`0x4AC9820` objc stubのselref slot `0x651E550`→メソッド文字列`selectionPadding`（低36bit pointer `0x58B5147`、SQLite stringsと一致）。つまり **TTAStatusBodyTextView.selectionPadding は TFNAttributedTextView.selectionPadding へのクラスメソッド転送**。具体的なpt定数は**XServiceLibraries側を解析するまで未確定**。
- OX-032で確認したoptions bit33 offの経路だけで `linkTapDetectionBottomPadding`の6.0と `selectionPadding`の戻り値がレイアウト式へ使われる。bit33 onはこの二つの値を0として処理する。**全ての本文セルの高さに6ptを足す、とは解釈しない**。
- `maximumSizeBlock`の設定元・invoke実体はこの追加検査の範囲では未解決。通常タイムラインの実際のbit33とdisplayTypeも未確認。アプリコード/main/バージョン未変更。

再現:
```sh
llvm-objdump -d --start-address=0x2cccbc0 --stop-address=0x2cccbf8 XAppLibraries
llvm-objdump --macho --dyld-info XAppLibraries | grep 6540D98
llvm-objdump -d --start-address=0x4ac9820 --stop-address=0x4ac9834 XAppLibraries
llvm-objdump --macho --section=__objc_selrefs --full-contents XAppLibraries | grep '^ 651e550'
```
