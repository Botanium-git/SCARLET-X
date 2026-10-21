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


## OX-034 — TFNAttributedTextView.selectionPadding = 2pt（2026-10-19）

一次資料: `/mnt/data/XServiceLibraries` SHA-256 `09e830331f35a7806f477cd0cbd497642461c44face5f818d39f9abd0b3040fc`（再計算一致）。元Mach-Oから`_OBJC_METACLASS_$_TFNAttributedTextView` nlist **0x44226A8** → ro **0x41C2D20** → relative methods **0x2F83590**（header `0x8000000C`, 3件）を手動解析し、relative entry **0x2F83598** のselector参照先 **0x43CA108** が `selectionPadding`（cstring VM **0x37344B4**）と一致、IMP **0xCB52A8** を解決。さらに元バイナリをllvm-objdumpで再検査:

```asm
0xCB52A8 fmov d0, #2.00000000
0xCB52AC ret
```

このため、OX-033で`TTAStatusBodyTextView.selectionPadding`から転送される **`TFNAttributedTextView.selectionPadding` は常に CGFloat 2.0pt**。同じくOX-033確認済みの`TTAStatusBodyTextView.linkTapDetectionBottomPadding = 6.0pt`と合わせると、OX-032で静的確認した **options bit33 offかつ本文幅・採用本文高が正の場合**:

- `W = bodyWidthCandidate + 2*2 = bodyWidthCandidate + 4pt`
- `H = acceptedBodyHeight + 6 + 2*2 = acceptedBodyHeight + 10pt`
- 同じ経路で`setAdditionalEdgeInsets:`へ負値を設定するため、**表示セルの最終上下余白が+10ptとは言えない**。
- **bit33 onでは両padding=0**で上記加算はしない。
- `maximumSizeBlock`の設定元・実際の通常タイムラインのbit33/displayTypeは引き続き未確定。この調査の対象は`selectionPadding`定数の検証であり、maximumSizeBlockの所有元まで解明したわけではない。実機未検証・アプリコード/main/バージョン未変更。

再現:
```bash
llvm-objdump --macho --syms XServiceLibraries | grep '_OBJC_METACLASS_\\$_TFNAttributedTextView'
llvm-objdump -d --start-address=0xcb52a0 --stop-address=0xcb52b0 XServiceLibraries
```


## OX-035 — maximumSizeBlockの所有クラス・ivarを解決（2026-10-19）

一次資料: X v12.25 T1Twitter SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`、XServiceLibraries SHA-256 `09e830331f35a7806f477cd0cbd497642461c44face5f818d39f9abd0b3040fc`（両方再計算一致）。各元Mach-Oのclass / relative method list / disassemblyおよびdyld chained bindを照合。

- T1Twitter `_OBJC_CLASS_$_T1StandardStatusBodyViewAdapter` at **0x1AF28B8** のsuperclass field **0x1AF28C0** はchained bind **`_OBJC_CLASS_$_TFNComposableViewAdapter` (XServiceLibraries)**。これはOX-029本文adapterの直接superclass。
- T1Twitter同クラスのown instance method list `0x13D15F0`（header `0x8000000C`、36件）を列挙すると、`maximumSizeBlock`/`setMaximumSizeBlock:`は含まれない。所有元は継承先。
- XServiceLibraries `_OBJC_CLASS_$_TFNComposableViewAdapter` **0x4423710** → class_ro → relative instance method list **0x2FB4810**（header `0x8000000C`、28件）を直接解析すると:
  - entry **0x2FB4944** `maximumSizeBlock` → IMP **0xCD8038**
  - entry **0x2FB4950** `setMaximumSizeBlock:` → IMP **0xCD8040**
- 実命令:
```asm
0xCD8038 ldr x0,[x0,#0x30]
0xCD803C ret
0xCD8040 mov w3,#0x30
0xCD8044 b 0x2ED6624
```
 getterはインスタンスoffset **0x30** から返す。setterは0x30を引数に共通の保存ルーチンへ分岐（当該保存ルーチンの詳細と参照/コピーsemanticは未検証）。
- **結論**: 本文adapterのサイズ上限制御に使う`maximumSizeBlock`はT1固有プロパティではなく、XServiceLibraries側の汎用`TFNComposableViewAdapter`から継承したもの。OX-030で見つかった`BLR`がそのblockをinvokeすることと合わせて、保存先は具体的に特定できた。
- **未解決**: `setMaximumSizeBlock:`の実呼出し元とblock invoke本体、どの本文表示条件で設定されるか、通常タイムラインの採用条件、表示時の具体的サイズ。T1Twitter自クラスにsetterがないことは、他クラス/生成処理がsetterを呼ぶかどうかの否定にはならない。アプリ本体/main/バージョン・実機検証なし。

再現コマンド:
```sh
llvm-objdump --macho --dyld-info T1Twitter | grep '0x1AF28C0'
llvm-objdump --macho --syms XServiceLibraries | grep '_OBJC_CLASS_\\$_TFNComposableViewAdapter'
llvm-objdump -d --start-address=0xcd8028 --stop-address=0xcd8048 XServiceLibraries
```


## OX-036 — `setMaximumSizeBlock:`の実呼び出し元とblock実装（2026-10-19）

対象: 提供された公式X v12.25 `T1Twitter` Mach-O。直接BL検索は**実行可能`__TEXT,__text`のBLエンコードをdecodeし、呼出先ObjC stubとのtarget完全一致**で実施。`setMaximumSizeBlock:` は`__objc_methname` VM **0x167482F**、`__objc_selrefs` slot **0x1AB9300**、`__objc_stubs` **0x13444E0**（ADRP/LDRが同selref slotを参照）と確認。

- **直接BL呼び出し35箇所**を確認（アドレス: `0x208530..0x208650`の16byte刻み19箇所、`0x20E0EC`, `0x20F3D0`, `0x2A7648`, `0x2C5214..0x2C5298`の12byte刻み12箇所、`0x329B88`; 合計35）。**35種類の本文用block、という意味ではない**。各receiverの型と生成条件で分類する必要がある。
- **実例：0x2A7648は本文用adapterとは別のreceiver**。直前の `0x2A7618..0x2A7628` でclassref slot `0x1AD48B8`からalloc/init相当の処理を行ってx23を保持。`dyld-info`ではslotが **class `0x1AEFB18`へrebase**、nlist class symbolは `_OBJC_CLASS_$_T1StandardStatusAttachmentViewAdapter`。すなわちこの呼出しは **attachment adapterへのmaximumSizeBlock設定**。同関数は`T1StandardStatusViewLayoutStateGenerator`の `_t1_viewAdapterSet`（IMP `0x2A7410`）の内部。
- `0x2A7630..0x2A7648`で x2をVM **0x187BB08** の定数blockオブジェクトへ設定して `setMaximumSizeBlock:` を呼ぶ。block objectのinvoke slot (VM +0x10) は **`0x2A8560`**。invokeの実命令:
```asm
0x2A8568 mov x0,x2
0x2A856C bl 0x12DB600  ; ObjC selector bodyWidth（OX-030/031で解決）
0x2A8570 fmov d1,xzr
0x2A8578 ret
```
  block引数のlayoutMetricsから `bodyWidth` を取得して、**CGSize(width=layoutMetrics.bodyWidth,height=0)** を返すblockと解釈できる。これは最大「高さ」を固定していない。注: 関数の引数register解釈はOX-030のblock invoke ABIとの整合で判断。
- 別の`setMaximumSizeBlock:`呼出例 `0x329B88`はstack上にblock literalを構築（`0x329B60..0x329B84`）、invoke function VM **0x329E70**。このinvokeは `bodyWidth` の戻り値にcapture objectのoffset `0x20`のdoubleを加算し、高さとしてd1=0を返す。**一律の本文高さ制限blockではない**。このcallerの正確なclass ownerと採用条件は未解決。
- 他の`0x20E0EC`および`0x20F3D0`でもstack上のblock literalを作成してsetterへ渡す命令列がある。selector callが確実でも、receiverを本文adapterと確定できるまでは通常タイムライン用と呼ばない。
- **未解決**: 35 callsiteの完全なreceiver/class分類、本文 `T1StandardStatusBodyViewAdapter` に実際にblockが設定されるか、本文用blockのinvoke本体と高さ成分、displayType/通常タイムライン採用条件。特に今回のattachment adapter blockを本文adapterの設定として転用しない。
- 元アプリコード/main/バージョンは未変更。静的解析のみ、実機検証なし。

再現:
```sh
llvm-objdump -d --start-address=0x2a7600 --stop-address=0x2a7650 T1Twitter
llvm-objdump -d --start-address=0x2a8560 --stop-address=0x2a857c T1Twitter
llvm-objdump -d --start-address=0x329b50 --stop-address=0x329ba0 T1Twitter
llvm-objdump -d --start-address=0x329e70 --stop-address=0x329ea0 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep 1AD48B8
```

**追加確認（OX-036）**: `0x208530..0x208650`の連続19 callsiteは、いずれもx2に**同一のglobal block** VM `0x1879160`を渡す（前半・後半の命令列を観察）。当該block literalのinvoke pointer (VM+0x10) は **`0x2088AC`**。その実命令は `mov x0,x2; bl 0x12E51E0; fmov d1,xzr; ret` であり、**戻りCGSizeの第二成分（高さ）は0**。`0x12E51E0`のselectorがまだ未解決のため、第一成分をbodyWidthと断定しない。この19件は**19個の独立したblock実装ではなく、同一blockを複数のadapterへ配布する設定**と読める。`0x208514..0x208520`の条件分岐の後でこの設定列へ入る。


## OX-037 — standard body adapterへのmaximumSizeBlock設定を二経路で確認（2026-10-19）

一次資料: 同一X v12.25 `T1Twitter` Mach-O、`scarlet_macho(1).sqlite`（メソッド候補照合のみ）。`llvm-objdump --macho --dyld-info T1Twitter`でclassref **0x1AD48A8 → rebase 0x1AF28B8**、`_OBJC_CLASS_$_T1StandardStatusBodyViewAdapter`と直接確認した。前回OX-036に記録した`setMaximumSizeBlock:` ObjC stub **0x13444E0**へのBLからreceiverと渡すblockを追跡した。

**経路A — `_t1_viewAdapterSetWithLayoutMetrics:` IMP 0x2080F4**
- `0x2081B4..0x2081CC`: classref slot 0x1AD48A8からalloc→初期化相当の呼び出しを行い、本文adapter生成結果を`[sp,#0x98]`へ格納する。
- `0x208534..0x208540`: x2にglobal block **0x1879160**を設定し、`ldr x0,[sp,#0x98]`→ `bl 0x13444E0`（`setMaximumSizeBlock:`）。よって**body adapterが直接setter receiver**である。
- 同blockのinvoke **0x2088AC** は `mov x0,x2; bl 0x12E51E0; fmov d1,xzr; ret`、少なくとも**CGSize高さ成分0**を返す。幅を取得するselector（objc selref 0x1AA1640）は未解決。
- **訂正・精密化**: OX-036は`0x208530..0x208650`の19か所を「同一block」と広く表現したが、実命令では`0x208530..0x208620`の**16か所**のみ同一block 0x1879160。`0x208630`は0x18791C0、`0x208640`/`0x208650`は0x1879180で**別block**。本文adapterの`0x208540`は確実に16か所の共通block側。

**経路B — `_t1_viewAdapterSetWithMaxWidth:` IMP 0x2C4FEC**
- `0x2C5030..0x2C505C`: メモリ上にblock literalを構築、invoke pointerに **0x2C53D4**を設定し、`_Block_copy`系処理の戻りを`[sp,#0x48]`へ格納。captured値としてd8（本関数入口のv0）も格納する。
- `0x2C5098..0x2C50B0`: 同じbody adapter classref slot **0x1AD48A8** を用いた生成処理、結果を `[sp,#0x58]` に格納する。
- `0x2C5208..0x2C5214`: `ldr x0,[sp,#0x58]`、`ldr x19,[sp,#0x48]`、`mov x2,x19`、`bl 0x13444E0`。従って**この経路でもbody adapterへ上記stack/copy blockを設定**する。
- block invoke **0x2C53D4** はcaptured double（block offset+0x20）を使うObjC呼び出し後、`0x2C5414 fmov d1,xzr`を実行し、高さ成分0を返す。幅成分がcaptured値そのものか、どのようなオブジェクト値と組み合わせるかはstubのselector/ABI解決前に断定しない。

**意味と制限**
- OX-032で実証した本文adapterの高さ採用規則は、`maximumSizeBlock.height > 0`のときのみAPI計測高さをcapし、0ならheight API結果を採用。上記**二経路の実blockはheight=0**なので、これらの経路ではblockが**正の高さ上限を与えていない**。
- ただし上記2箇所がすべての本文adapter生成経路を網羅している証拠はまだない。ほかのsetter callsiteやruntimeでのblock差替えの有無、実際の通常タイムライン利用は未確定。現段階で「公式Xは本文最大行数・高さを制限しない」と一般化しない。
- 本文adapterへのblock設定元を**実装アドレスまで確定した**のがOX-037の成果。実機未計測。アプリ本体/main/バージョン変更なし。

再現:
```sh
llvm-objdump --macho --dyld-info T1Twitter | grep 1AD48A8
llvm-objdump -d --start-address=0x2081b0 --stop-address=0x2081d0 T1Twitter
llvm-objdump -d --start-address=0x208520 --stop-address=0x208658 T1Twitter
llvm-objdump -d --start-address=0x2c5030 --stop-address=0x2c5060 T1Twitter
llvm-objdump -d --start-address=0x2c5090 --stop-address=0x2c50b4 T1Twitter
llvm-objdump -d --start-address=0x2c5200 --stop-address=0x2c5224 T1Twitter
llvm-objdump -d --start-address=0x2c53d4 --stop-address=0x2c5428 T1Twitter
```


## OX-038 — OX-037の2生成経路は引用投稿ビューとDM投稿ビューのクラスメソッド（2026-10-19）

一次資料: 提供された公式X v12.25の`T1Twitter` Mach-O（読取のみ）、およびSQLiteのimp/list候補。開始時のdevelop HEADは`f504628d7d49521c55364b9422c6da86dad7d2e7`（前回とidentical）。元Mach-Oの`_OBJC_METACLASS_$_...` nlist→class_ro→relative method list (header `0x8000000C`)→entry相対IMPを**直接突き合わせ**、さらにselector名はrelative entryのname fieldが指す**selrefポインタを1回解決**して検証した。

### 生成経路Aの実owner：`T1QuotedStandardStatusView`（引用投稿ビュー）
- `_OBJC_METACLASS_$_T1QuotedStandardStatusView` nlist **0x1AEAF78** → meta class_ro **0x197C668**（内部のclass name `T1QuotedStandardStatusView`と一致）→ relative method list **0x1392710**。
- index **6**, relative entry **0x1392760**、selector selref **0x1A9BC30** → cstring **`_t1_viewAdapterSetWithLayoutMetrics:`**、method type **`@24@0:8@16`**、IMP **0x2080F4**。
- 従ってOX-037で確認した`0x208540`の本文adapterへの`setMaximumSizeBlock:`は、**`+[T1QuotedStandardStatusView _t1_viewAdapterSetWithLayoutMetrics:]`内**の処理。これはメソッド名とownerから引用投稿ビュー向けの生成経路と判明したが、外側の通常タイムラインで**引用表示される可能性**は排除しない。

### 生成経路Bの実owner：`T1DirectMessageConversationStatusView`（DM内投稿ビュー）
- `_OBJC_METACLASS_$_T1DirectMessageConversationStatusView` nlist **0x1AEDE58** → meta class_ro **0x19902F0**（内部class name一致）→ relative method list **0x13917C8**。
- index **1**, entry **0x13917DC**、selector selref **0x1A9BC38** → cstring **`_t1_viewAdapterSetWithMaxWidth:`**、method type **`@24@0:8d16`**、IMP **0x2C4FEC**。
- よってOX-037の`0x2C5214` setterは **`+[T1DirectMessageConversationStatusView _t1_viewAdapterSetWithMaxWidth:]`内**。通常のホームタイムライン本文生成へ直接当てはめない。

### 解釈更新と制限

OX-037が示したのは「少なくとも2か所でbody adapterをreceiverに`maximumSizeBlock`が設定され、両blockの高さ成分は0」という**実コード上の事実**で、**通常タイムラインの普通の投稿に同設定が使用される証拠ではなかった**。OX-038でownerを確認した結果、少なくともこの2箇所は**引用投稿ビュー / DM投稿ビュー**のクラスメソッドだった。通常のホームタイムラインの標準投稿について、blockの設定有無・値は依然未確定。

今回の調査ではmethod ownerおよびメソッド型までは実Mach-Oで確認済み。ただし、この2メソッドの**全外部呼び出し元**を網羅したわけではなく、実行時の採用・再利用や画面表示条件を確定したわけではない。次は`T1StandardStatusViewLayoutStateGenerator._t1_viewAdapterSet`など普通の投稿に近い生成処理の本文adapterの設定/未設定と呼び出し元、`maximumSizeBlock`のwidth getter `0x12E51E0`のselectorを調べる。

アプリ本体・main・バージョン変更なし。実機検証なし。

再現:
```sh
llvm-objdump --macho --syms T1Twitter | grep -E 'OBJC_METACLASS_\\$_(T1QuotedStandardStatusView|T1DirectMessageConversationStatusView)'
llvm-objdump -d --start-address=0x2080f4 --stop-address=0x208160 T1Twitter
llvm-objdump -d --start-address=0x2c4fec --stop-address=0x2c5040 T1Twitter
```


## OX-039 — StandardStatus generator: body creation vs attachment maximumSizeBlock (2026-10-19)

Primary binary: T1Twitter SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd` (rechecked). In `_t1_viewAdapterSet` IMP `0x2A7410`, `0x2A75C4` loads classref `0x1AD48A8`, rebased to `T1StandardStatusBodyViewAdapter` class `0x1AF28B8`; calls alloc stub at `0x2A75C8`, initializer stub `0x13055A0` at `0x2A75D8` with w2=14,x3=0,x4=0, and saves object in x21 at `0x2A75DC`. Exact initializer selector and meaning of 14 require further resolution.

Separately `0x2A7618..0x2A762C` allocates `T1StandardStatusAttachmentViewAdapter` via classref `0x1AD48B8`; its instance is x23. At `0x2A7648`, the receiver is this x23, argument x2 global block `0x187BB08`, and target objc stub `0x13444E0` is `setMaximumSizeBlock:`. A search of disassembled instructions over `0x2A7410..0x2A8560` found only this one direct BL to that setter stub, not a direct call with the body adapter as receiver. This does NOT exclude indirect dispatch, setters elsewhere, or default blocks, and does not prove home timeline runtime conditions or nil block state. The block's zero height concerns attachment, not body. Source app unchanged.

Reproduce with `llvm-objdump -d --start-address=0x2a75c0 --stop-address=0x2a7650 T1Twitter`, and dyld-info rebase entries for `0x1AD48A8` and `0x1AD48B8`.


## OX-040 — standard body adapter initializer arguments resolved (2026-10-19)

Primary source: supplied T1Twitter Mach-O, inspected at 0x13055A0 and 0x2A75C0..0x2A75DC with llvm-objdump. The objc stub at 0x13055A0 loads selector reference slot **0x1AA9730** (ADRP 0x1AA9000 + LDR offset 0x730). The slot's low-36-bit pointer resolves to the Objective-C method name **`initWithViewIdentifier:displayType:displayLocation:`**. This agrees with the previously validated `T1StandardStatusBodyViewAdapter` instance-method owner/IMP `0x3BA434` (OX-029).

The standard generator (`-[T1StandardStatusViewLayoutStateGenerator _t1_viewAdapterSet]` at 0x2A7410) reads body adapter classref 0x1AD48A8 at 0x2A75C4, allocates at 0x2A75C8, then supplies these literal initializer arguments: `0x2A75CC mov w2,#0xE` **viewIdentifier=14**, `0x2A75D0 mov x3,#0` **displayType=0**, `0x2A75D4 mov x4,#0` **displayLocation=0**, followed by `0x2A75D8 bl 0x13055A0`. The resulting body adapter is saved in x21 at 0x2A75DC.

**Correction to OX-039**: The integer 14 is **not** the body text displayType; it is `viewIdentifier`. This generator's constructed body adapter is explicitly initialized with **displayType 0**. This is a verified static initialization value, not a direct runtime measurement of which generator the home timeline uses. Selector names are resolved from actual Mach-O selector references rather than guessed from call signatures.

The previous OX-039 scope remains unchanged: the directly observed `setMaximumSizeBlock:` at 0x2A7648 is addressed to the attachment adapter, not this body adapter. No conclusion about later indirect/default maximumSizeBlock or actual home timeline selection. No app code, main, or version change.

Reproduce: `llvm-objdump -d --start-address=0x13055a0 --stop-address=0x13055b4 T1Twitter` and `llvm-objdump -d --start-address=0x2a75c0 --stop-address=0x2a75e0 T1Twitter`; decode selref 0x1AA9730 in the original Mach-O.


## OX-041 — Standard layout generator direct-call scan boundary (2026-10-19)

Read-only inspection of supplied `T1Twitter` Mach-O and SQLite method index. The `objc_methods` index has selector `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` at IMP **0x2AE63C** with method list **0x13D2F00** (already owner-resolved as `T1StandardStatusViewLayoutStateGenerator` in OX-025). Its `_t1_viewAdapterSet` is **0x2A7410** (OX-039/040). Re-inspected `0x2AE63C..0x2AE730` in original `llvm-objdump` to confirm the entry and register arguments.

Performed an exhaustive, 4-byte-aligned ARM64 **immediate BL** target scan over the Mach-O `__TEXT,__text` VM range **0x4000..0x129A124**, using opcode mask `(instruction & 0xFC000000) == 0x94000000`, 26-bit signed displacement and destination `PC + (imm26 << 2)`. **Zero direct BL instructions target 0x2AE63C**, and **zero target 0x2A7410** in that range. This is a narrow **negative result for direct branch instructions only**, not evidence that either method is never called. Objective-C method dispatch through selector/`objc_msgSend`, blocks, function pointers, or dynamic replacement is not covered by this scan; particularly `layoutStateForViewModel:...` is a plausible selector-dispatched entry.

Consequently there is **still no demonstrated ordinary home-timeline runtime caller** of this generator. The static body-adapter `displayType=0` proven in OX-040 cannot yet be generalized to all home timeline posts. The proper next step is to find selector-dispatch callsites and identify receiver class/provenance, then view-model/display conditions. No app code, main, or version modification and no on-device observation.

Reproduce: obtain executable `__text` from `llvm-objdump --macho --section-headers T1Twitter`, scan each 32-bit word for ARM64 BL and sign-extend imm26. Compare decoded target addresses to `0x2AE63C` and `0x2A7410`. SQLite query `select selector,imp,list_address from objc_methods where imp=2811452` confirms indexed method row but is not alone proof of runtime use.


## OX-042 — objc selector dispatch callsite discovery (2026-10-19)

Source: supplied T1Twitter Mach-O, inspected read-only. `__objc_stubs` range `0x12B0C20..0x1374280`, `__objc_selrefs` `0x1A91BA8..0x1AD0410`, executable `__text` `0x4000..0x129A124`. An ADRP(x1)+LDR(x1) selector-reference resolver maps Objective-C stub **0x1314C80** to selref **0x1AAD4E8**, whose target is **`layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:`**. The binary's aligned ARM64 BL immediate-target scan locates **7 direct BLs to this selector stub**, at **0x25F400, 0x25FEC0, 0x2A8B30, 0x2EF85C, 0x32A678, 0x32A90C, 0x8498F0**.

All seven are `objc_msgSend`-style **selector-stub calls**, not direct calls to the standard generator's IMP `0x2AE63C`. This resolves why OX-041's direct-to-IMP scan was negative, while leaving open which runtime class receives each message. Examples: 0x2A8B18 sets x0 from x22 and marshals viewModel/options/account/layoutMetrics/previous state into x2..x6 before 0x2A8B30; 0x25F3E8 similarly receives x0=x22; 0x25FEA8 sets x0=x21; 0x2EF844 sets x0=x25. The final receiver classes / exact provenance remain **unverified**. In particular, **none of these has been proved to dispatch to `T1StandardStatusViewLayoutStateGenerator` on the normal home timeline**. Other dynamically formed calls and other Mach-Os are outside the scan scope.

Reproduce by parsing `__objc_stubs` ADRP+LDR selector addresses and scanning `__text` ARM64 BL imm26 branches; disassemble e.g. `llvm-objdump -d --start-address=0x2a8ae8 --stop-address=0x2a8b40 T1Twitter`. No app/main/version edits or runtime tests.


## OX-043 — receiver provenance at 0x2A8B30: layoutStateGenerator getter (2026-10-19)

Primary evidence: supplied T1Twitter Mach-O, read-only `llvm-objdump` of `0x2A8A80..0x2A8B50` and direct decoding of objc stub `0x1314CC0` selector-ref slot `0x1AAD4F8` (low-36-bit pointer to method string `layoutStateGenerator` at VM `0x1637030`). `0x2A8A9C mov x20,x0` saves `self`; `0x2A8AA8 mov x0,x20; 0x2A8AAC bl 0x12B03D8; 0x2A8AB0 bl 0x1314CC0` sends `layoutStateGenerator` after an intermediate runtime helper (`0x12B03D8` role not yet established), then `0x2A8ABC mov x22,x0` stores retained return. Later `0x2A8B18 mov x0,x22; 0x2A8B1C..0x2A8B2C` marshal arguments x2..x6 and `0x2A8B30 bl 0x1314C80` sends `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:`. Thus the target selector's receiver at this callsite is **the returned layoutStateGenerator property**, rather than a hardcoded directly allocated `T1StandardStatusViewLayoutStateGenerator` in the shown instructions.

Other selector stubs in the argument-gathering sequence are not fully decoded here, and the containing method owner, property backing assignment, actual returned class and normal-home-timeline runtime dispatch are **not yet verified**. In particular this does **not** prove the getter returns the standard generator for all call contexts. OX-042 other six callsites remain to be traced. App code/main/version untouched.

Reproduce: `llvm-objdump -d --start-address=0x2a8a80 --stop-address=0x2a8b50 T1Twitter`; `llvm-objdump -d --start-address=0x1314cc0 --stop-address=0x1314cd4 T1Twitter`; decode pointer at `__objc_selrefs` 0x1AAD4F8.


## OX-044 — T1StandardStatusView owns the callsite and initializes its standard generator (2026-10-19)

Primary source: supplied T1Twitter Mach-O, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`. Read-only native nlist Objective-C class/metaclass ro/relative method list ownership validation (not relying only on the indexed sqlite names), then llvm-objdump of `0x2A73A0..0x2A7410` and `0x2A8A80..0x2A8B34`; dyld chained rebase checked.

- The containing instance method at IMP **0x2A8A80** is **`-[T1StandardStatusView _t1_updateLayoutStateWithLayoutMetrics:]`**, owned by `_OBJC_CLASS_$_T1StandardStatusView` method list **0x13D2A18**. It invokes `layoutStateGenerator` selector at **0x2A8AB0**; stores result in x22 at **0x2A8ABC** and passes x22 as receiver to `layoutStateForViewModel:options:account:layoutMetrics:withPreviousLayoutState:` at **0x2A8B30** (OX-043).
- The **class method** `+[T1StandardStatusView layoutStateGenerator]` owns IMP **0x2A73A0** (its metaclass relative-method list **0x1392F00**). It checks a guarded lazy/singleton-like cached object reference at data VM **0x1BBEF08** and a guard at **0x1BBEF10**, returning the retained/released cached value in `0x2A73BC..0x2A73D8`, or calling initialization helper `0x12906F0` at **0x2A73DC**. These references are not necessarily stable across processes; this is static code semantics, not runtime observation.
- The associated local initializer at **0x2A73E4** loads classref **0x1AD53C8** and calls `0x12B030C`; `llvm-objdump --macho --dyld-info T1Twitter` proves this slot rebases to **0x1AED818 `_OBJC_CLASS_$_T1StandardStatusViewLayoutStateGenerator`**. It stores returned object to **0x1BBEF08** at **0x2A7400**. This provides a **concrete static link from `T1StandardStatusView.layoutStateGenerator` caching/initialization path to `T1StandardStatusViewLayoutStateGenerator`**. The exact helper/alloc initialization semantics and guard implementation are not individually proven.
- OX-040 demonstrated that the generator's `_t1_viewAdapterSet` constructs a body adapter using `viewIdentifier=14, displayType=0, displayLocation=0`. Together, static connections now support **T1StandardStatusView → layoutStateGenerator getter → standard generator instance → layoutState method**, plus generator's body-adapter setup. This is **NOT** proof that ordinary home timeline always uses T1StandardStatusView in a given account/UI mode, nor on-device font or height values.
- No application source code, version, main or user device changed. Next: identify where T1StandardStatusView is placed/selected and investigate potential alternate timeline view implementations.

Reproduce with `llvm-objdump -d --start-address=0x2a73a0 --stop-address=0x2a7410 T1Twitter`, `llvm-objdump -d --start-address=0x2a8a80 --stop-address=0x2a8b38 T1Twitter`, and dyld-info lookup of `0x1AD53C8`.


## OX-045 — T1StandardStatusView class references: static reachability, not timeline adoption (2026-10-19)

Source: supplied T1Twitter v12.25 Mach-O. The `_OBJC_CLASS_$_T1StandardStatusView` symbol resides at **0x1AED840**. Original dyld chained-rebase entries identify `__objc_classrefs` slot **0x1AD3E30** as pointing to this class; this is distinct from the standard generator classref established in OX-044. The classref is used from multiple functions in the binary, so the class is statically referenced.

One concrete reference: `0x2A86E8 adrp x8,0x1AD3000` and `0x2A86EC ldr x0,[x8,#0xE30]` load the `T1StandardStatusView` class object. At `0x2A86F0 bl 0x1314DA0`, the Objective-C selector stub resolves through selref **0x1AAD530** to **`layoutTracingSamplingFractionalPercentage`** (verified from its ADRP/LDR and selref string). The return value goes in x2 to the next call at `0x2A8700`. Hence **this classref use concerns layout tracing configuration**, not proof of `T1StandardStatusView` instance allocation/placement in a home timeline.

Other nearby classref occurrences at `0x2AE604..0x2AE608` and `0x2AE6F8..0x2AE6FC` are inside/near the standard-generator implementation and likewise cannot be taken as proof of a home-timeline owning controller. The class reference lookup alone does not identify which screens instantiate T1StandardStatusView or whether alternate status views are used. OX-044 already proves the internal `T1StandardStatusView -> standard generator -> body adapter` static link; **home timeline runtime selection is still unverified**.

Next: find concrete allocation/factory or reusable-cell class from a likely timeline controller, with receiver and selected class confirmed by code/dataflow; do not equate any classref with actual UI placement. No code/main/version changes, no real-device measurements.

Reproduce: `llvm-objdump --macho --dyld-info T1Twitter | grep 1AD3E30`, `llvm-objdump -d --start-address=0x2a86dc --stop-address=0x2a8708 T1Twitter`, and `llvm-objdump -d --start-address=0x1314da0 --stop-address=0x1314db0 T1Twitter` (selector reference at `0x1AAD530`).


## OX-046 — T1StatusCell delegates layout state and frames to an internal view (2026-10-19)

Source: supplied official X v12.25 `T1Twitter` Mach-O, `llvm-objdump -d` inspected at `0x2F09F4..0x2F0BE4`; ObjC stub ADRP/LDR selrefs resolved from the original binary. All addresses are unslid VM addresses.

- Previously verified `-[T1StatusCell setCellLayout:]` IMP **0x2F09F4**: `0x2F0A4C..0x2F0A58` reads an object from a T1StatusCell ivar using the offset encoded at VM **0x1ADD804**; `0x2F0A5C bl 0x13431A0` sends **`setLayoutState:`** to that object, with layout-state argument x2. This confirms the cell forwards a layout state to an internally held object. The precise runtime class of that object remains unresolved.
- `-[T1StatusCell layoutSubviews]` IMP **0x2F0B74**: `0x2F0BA8 bl 0x12E5040` sends **`contentView`**, `0x2F0BB8 bl 0x12DBCE0` sends **`bounds`**, then `0x2F0BC4..0x2F0BC8` loads the same internally held object and sends **`setFrame:`** via stub **0x133F080**. Thus the cell explicitly sets its inner view's frame from a CGRect produced on this path. This is layout behavior, not proof of which status view implementation is inside.
- `-[T1StatusCell sizeThatFits:]` IMP **0x2F0BE4** reads the same ivar and tail-calls stub **0x1306D60**, resolving to **`intrinsicContentSize`**. Therefore cell sizing delegates the size query to the same internal object, rather than directly reimplementing the text-height math in this method.
- In adjacent method code `0x2F0A84..0x2F0B70`, the internal object also receives **`setViewModel:options:account:`** through ObjC stub **0x1352060**. This supports a cell-to-status-view data update path, without establishing whether this is invariably `T1StandardStatusView`.

**Limits:** The ivar's name, assignment/constructor origin, concrete class, cell registration ownership, and ordinary home-timeline selection are not proved here. Merely possessing `setLayoutState:`, `intrinsicContentSize`, and `setViewModel:options:account:` does not distinguish `T1StandardStatusView` from alternative status-view classes. Next inspect T1StatusCell initialization, ivar metadata, and any factory/selection callsites. No app/main/version changes or device runtime testing.

Reproduce: `llvm-objdump -d --start-address=0x2f09f4 --stop-address=0x2f0bf4 T1Twitter`; inspect ObjC stubs at `0x13431A0`, `0x133F080`, `0x1306D60`, `0x1352060`, `0x12E5040`, `0x12DBCE0` and their selrefs.


## OX-047 — T1StatusCell inner status view is chosen through statusViewClass (2026-10-19)

Primary evidence: official X v12.25 IPA, freshly extracted `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`; disassembly of original Mach-O with LLVM. `_OBJC_CLASS_$_T1StatusCell` at `0x1AEF370`, class_ro `0x1996E28`, relative method list `0x13D37C0` (61 methods). Owner-resolved instance methods: `initWithStyle:reuseIdentifier:` **0x2EF97C** and `statusViewWithFrame:` **0x2F099C** (in addition to OX-046 methods).

In `-[T1StatusCell initWithStyle:reuseIdentifier:]`, `0x2EF9B4..0x2EF9CC` obtains cell bounds and calls objc stub **0x135CC00**, selector ref `0x1ABF4C8` → **`statusViewWithFrame:`**. Its return value is retained and saved into the same cell ivar whose *ivar offset pointer* is `0x1ADD804` (at `0x2EF9CC..0x2EF9D8`). The cell then sends a method via stub `0x133E160` to the saved object and adds it to a content view via stub `0x12D3BC0`; their exact selector names should be checked before labeling these individual operations.

The method `-[T1StatusCell statusViewWithFrame:]` at **0x2F099C** calls runtime helper `0x12B03D8` followed by objc stub **0x135CB40**. The stub's selref `0x1ABF498` resolves to **`statusViewClass`**. Then `0x2F09C4` calls alloc stub `0x12B02F4`, and `0x2F09E0` calls objc stub **0x12FFE60**, selref `0x1AA8160` → **`initWithFrame:isInCell:isDarkBackground:`**. Registers set w2=1 and w3=0, with CGRect values passed in floating-point register group. Thus the concrete view class is **obtained through `statusViewClass`**, rather than an explicitly hardcoded `T1StandardStatusView` classref within this factory.

**Conclusion:** An actual creation/ownership bridge is now verified: `T1StatusCell.initWithStyle:reuseIdentifier:` → `statusViewWithFrame:` → class returned by `statusViewClass` → `initWithFrame:isInCell:isDarkBackground:` → saved cell ivar → layout/delegation proven in OX-046. The concrete `statusViewClass` implementation and any subclasses/overrides or selection by specific timeline controllers have **not** been resolved. Therefore this proves that the cell obtains an inner status view, but **does not prove** it must be `T1StandardStatusView` for regular home posts. `isInCell=1`, `isDarkBackground=0` are the immediate arguments of the observed factory; runtime conditions and subclasses remain subject to verification. App code and main not touched; no version bump or device verification.

Reproduce:
```sh
llvm-objdump -d --start-address=0x2ef97c --stop-address=0x2efa10 T1Twitter
llvm-objdump -d --start-address=0x2f099c --stop-address=0x2f09f4 T1Twitter
llvm-objdump -d --start-address=0x135cb40 --stop-address=0x135cb54 T1Twitter
llvm-objdump -d --start-address=0x12ffe60 --stop-address=0x12ffe70 T1Twitter
```


## OX-048 — T1StatusCellのstatusViewClass実装と会話用overrideを確認（2026-10-20）

一次資料: 提供された公式X v12.25の`T1Twitter` Mach-O。IPA内の`Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`から再展開し、SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`を確認。SQLiteの`objc_methods`にselector `statusViewClass` が2行（IMP `0xC008`、`0x2EF7B8`）あり、**元Mach-Oのnlist symbol → metaclass class_ro → relative method list → selector selref → IMP**を独立に突き合わせた。

| owner (メタクラス) | class address | relative method list | entry | IMP | classrefと返すクラス |
|---|---|---|---|---|---|
| `+[T1StatusCell statusViewClass]` | `0x1AEF398` | `0x1392FC0` | `0x1392FC8` | **`0x2EF7B8`** | slot `0x1AD3E30` → `T1StandardStatusView` `0x1AED840` |
| `+[T1ConversationFocalStatusViewTableViewCell statusViewClass]` | `0x1AE11F8` | `0x1391510` | `0x1391518` | **`0xC008`** | slot `0x1AD1828` → `T1ConversationFocalStatusView` `0x1AED2F0` |

両メソッドの実命令は、classrefをロードしruntime helper `0x12B03D8`へtail branchする短い実装。helperの個別内部実装は本調査の対象外。classrefの対応関係は`llvm-objdump --macho --dyld-info T1Twitter`の**rebase**とクラスnlist名称から直接確認。

```asm
0x2EF7B8 adrp x8,0x1AD3000
0x2EF7BC ldr  x0,[x8,#0xE30]  ; T1StandardStatusView classref 0x1AD3E30
0x2EF7C0 b    0x12B03D8

0xC008   adrp x8,0x1AD1000
0xC00C   ldr  x0,[x8,#0x828]  ; T1ConversationFocalStatusView classref 0x1AD1828
0xC010   b    0x12B03D8
```

**静的な接続の到達点**: OX-047で確定した`T1StatusCell.initWithStyle:reuseIdentifier:` → `statusViewWithFrame:` → `statusViewClass`を、今回の標準クラス実装で具体化できた。**T1StatusCell標準のクラス選択経路**は`T1StandardStatusView`を返す。OX-044の`T1StandardStatusView → T1StandardStatusViewLayoutStateGenerator`、OX-040のbody adapter (`displayType=0`)、OX-030/032の`TTAStatusBodyTextView`との接続まで、**標準セルから本文ビューへの実装上の静的チェーン**が成立する。

**制限**: これはObjective-C静的実装の結論であって、通常のホームタイムラインが実際に`T1StatusCell`を登録/生成する条件、別subclassの置換、runtime method-swizzlingなどは未検証。少なくとも`T1ConversationFocalStatusViewTableViewCell`という別の`statusViewClass`実装があるため、すべての投稿表示に標準ビューを一般化しない。他フレームワークやcategoryの動的上書きの網羅調査は未実施。アプリ本体/main/バージョン未変更、公式X実機検証なし。

再現:
```sh
llvm-objdump -d --start-address=0x2ef7b8 --stop-address=0x2ef7c4 T1Twitter
llvm-objdump -d --start-address=0xc008 --stop-address=0xc014 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep -E '1AD3E30|1AD1828'
llvm-objdump --macho --syms T1Twitter | grep 'OBJC_METACLASS_.*T1StatusCell'
```


## OX-049 — T1StatusCell classref use is a safe cast; timeline registration still unresolved (2026-10-20)

Read-only source: supplied official X v12.25 `T1Twitter` Mach-O and `scarlet_macho(1).sqlite`. Confirmed `T1StatusCell` symbol class VM **0x1AEF370** and chained-rebase classref **0x1AD1F08** (distinct from metaclass and superref entries) with `llvm-objdump --macho --dyld-info`.

Concrete classref use at **0x3F158..0x3F16C**: `adrp x8,0x1AD1000`, `ldr x0,[x8,#0xF08]`, runtime helper `0x12B03D8`, `mov x2,x0`, `mov x0,x19`, `bl 0x1366440`. Original stub `0x1366440` loads selector reference **0x1AC1AD8**, which resolves to **`tfs_safeCastAsClass:`**. Thus **this is a checked cast of the x19 object to T1StatusCell**, NOT construction, registration, or proof of home timeline use. The following stub `0x135CB20` resolves to **`statusView`** (selref **0x1ABF490**) and is called on the cast result. The enclosing method owner, original x19 object source, and screen still need owner/dataflow analysis.

Separate sqlite selector-index survey (candidate list only) found **three `statusCellClass` implementations** within T1Twitter with unslid IMPs **0xE2FE44**, **0x295D70**, **0x41E0B8** (decimal 14876228, 2710896, 4317368). These candidates may be factory/selection clues, but the current scan has not resolved their actual class/metaclass owners, implementations, or whether the home timeline calls them. They must not be described as verified timeline selectors without first validating metadata and calls in the Mach-O. `tableView:cellForRowAtIndexPath:` also has multiple indexed implementations; none was identified as the home timeline owner in this pass.

**Scope/conclusion:** OX-048 proved standard T1StatusCell factory selects T1StandardStatusView, while OX-049 still does **not** establish that the home timeline uses that cell. The explicit example classref is a cast, not allocation. Further work: verify `statusCellClass` owner and return class and inspect potential timeline data sources. No Scarlet X code/main/version changes or official app runtime test.

Reproduce: `llvm-objdump --macho --dyld-info T1Twitter | grep 1AD1F08`; `llvm-objdump -d --start-address=0x3f144 --stop-address=0x3f184 T1Twitter`; `llvm-objdump -d --start-address=0x1366440 --stop-address=0x1366454 T1Twitter`. Decode selector refs `0x1AC1AD8` and `0x1ABF490` in original Mach-O.


## OX-050 — statusCellClass owners and return values (2026-10-20)

Primary source: provided X v12.25 T1Twitter Mach-O, read-only. Revisited OX-049's SQLite candidate selector `statusCellClass` and independently parsed native nlist metaclasses, ro data and relative Objective-C method lists (`0x8000000C` entries) for all three IMPs. Class references decoded from original Mach-O `__objc_classrefs` rebase data.

| Owner (class method) | Metaclass | Relative method list | IMP | Return |
|---|---|---|---|---|
| `+[T1TweetSelectionTableRowAdapter statusCellClass]` | `0x1BA0C30` | `0x1375CD0` | `0xE2FE44` | nil class (`mov x0,#0; b 0x798410`) |
| `+[T1ConversationFocalStatusTableRowAdapter statusCellClass]` | `0x1AED700` | `0x13914C0` | `0x295D70` | classref `0x1AD5280` → `T1ConversationFocalStatusViewTableViewCell` class `0x1AE1220` |
| `+[T1StatusTableRowAdapter statusCellClass]` | `0x1AF4640` | `0x1393250` | `0x41E0B8` | classref `0x1AD1F08` → `T1StatusCell` class `0x1AEF370` |

Both non-nil methods load their classrefs into x0 and tail-branch to runtime helper `0x12B03D8`. The first returns nil via a distinct helper `0x798410`, whose finer retain behavior is not assessed; x0 is explicitly zero. The owner/selector/IMP identities were verified from relative method entries, not simply inferred from class or method names.

**Static link:** If `T1StatusTableRowAdapter`'s `statusCellClass` is used, the selected cell class is `T1StatusCell`. OX-048 shows the latter's default `statusViewClass` is `T1StandardStatusView`, enabling the complete static adapter→cell→standard status view→layout generator→body adapter→TTAStatusBodyTextView chain. This does **not** yet prove the ordinary home timeline uses `T1StatusTableRowAdapter`, nor the conditions for alternate row adapters or dynamic runtime overrides. Follow the row adapter factory/data-source selection next. No app/main/version change and no official-X runtime measurements.

Reproduce: `llvm-objdump -d --start-address=0xe2fe44 --stop-address=0xe2fe54 T1Twitter`; similarly ranges `0x295d70..0x295d7c` and `0x41e0b8..0x41e0c4`; dyld-info search `1AD5280`/`1AD1F08`.


## OX-051 — Home-timeline selector index addresses are not executable IMPs (2026-10-20)

Primary source: supplied official X v12.25 `T1Twitter` Mach-O re-extracted from `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`, plus supplied `scarlet_macho(1).sqlite`. No live X injection or binary edits.

**Important indexing limitation found during home-timeline adapter tracing:** In this SQLite database, the `objc_methods.imp` field for the home-timeline factory selectors below gives addresses **inside the `__TEXT,__objc_methlist` section**, not executable code. Therefore treating these integer values as actual method IMPs and disassembling them is incorrect.

| Indexed selector | SQLite `imp` integer | Hex VA | Native section |
|---|---:|---:|---|
| `homeTimelineContainerViewControllerWithAccount:homeTimeline:countryFilteredTimeline:latestTimeline:rankedFollowingTimeline:titleViewPlugins:barButtonItemPlugins:` | 21091028 | `0x141D2D4` | `__TEXT,__objc_methlist` |
| `homeTimelineItemsViewControllerWithAccount:timeline:` | 21091040 | `0x141D2E0` | `__TEXT,__objc_methlist` |
| `urtHomeTimelineStreamFactoryWithApplicationLink:homeConfiguration:` | 21091052 | `0x141D2EC` | `__TEXT,__objc_methlist` |

The native Mach-O load commands show `__TEXT,__text` begins at `0x4000` and has size `0x1296124`; `__TEXT,__objc_methlist` begins at `0x1374280` and has size `0xA9B94`. All three addresses above fall inside the **metadata** section, far outside executable `__text`. Indeed `llvm-objdump -d --start-address=0x141d2b0 --stop-address=0x141d320` emits no instructions. This finding does **not** disprove those selectors or factory methods; it shows that the index alone does not provide their implementation bodies. The exact meaning/encoding of the indexed record is not yet established and must not be guessed.

**What is established:** X v12.25 contains indexed home-timeline-related selectors, including `homeTimelineItemsViewControllerWithAccount:timeline:` and a home-container factory selector; the SQLite `imp` values above are **not independently verified IMPs**. No home data-source → `T1StatusTableRowAdapter` factory edge was established in this pass. OX-050's conditional adapter→cell chain remains valid, but it must not be labeled as a confirmed home-timeline runtime path.

**Next:** Parse the original Objective-C metadata at these `__objc_methlist` records (owner class, list layout, selector and relative implementation encoding) and follow actual resolved executable IMPs to identify timeline item adapter selection. Verify any claimed `T1StatusTableRowAdapter` creation against concrete classrefs, selectors, and disassembly before connecting it to the home timeline.

Reproduce:
```sh
sha256sum T1Twitter
llvm-objdump --macho --private-headers T1Twitter
llvm-objdump -d --start-address=0x141d2b0 --stop-address=0x141d320 T1Twitter
python3 - <<'PY'
import sqlite3
db=sqlite3.connect('scarlet_macho(1).sqlite')
for selector in ('homeTimelineItemsViewControllerWithAccount:timeline:', 'urtHomeTimelineStreamFactoryWithApplicationLink:homeConfiguration:'):
    print(selector,db.execute('select imp from objc_methods where selector=?',(selector,)).fetchall())
PY
```

Scope: diagnostics only on `develop`, no app code/main/version changes, no official X runtime claims.


## OX-052 — Home timeline factory selectors belong to a Swift ObjC protocol, NOT concrete implementations (2026-10-20)

Primary evidence: supplied X v12.25 `T1Twitter` Mach-O (SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`) plus SQLite `objc_methods` rows for `list_address=0x141D2B8`. Analysis read-only.

**Resolved OX-051 ambiguity:** At native VM address **`0x141D2B8`**, the method-list header is `entsizeAndFlags=0x8000000C`, `count=8`. Each of the eight relative 12-byte entries has **IMP delta equal to zero**. The SQLite `imp` numbers such as `0x141D2E0` point to the **address of the implementation-offset field within an entry**, rather than the address of compiled code. Specifically, entry #2 for `homeTimelineItemsViewControllerWithAccount:timeline:` begins at `0x141D2D8`, with its `imp` field at `0x141D2E0`; that 4-byte field contains zero. This is expected for **protocol method descriptions**, not evidence of a missing home feature at runtime.

The original Mach-O's chained rebase data points from `__DATA,__objc_const` slot **`0x1A38C98`** directly to method-list **`0x141D2B8`**. The containing protocol structure begins at **`0x1A38C80`** (also referenced by `__DATA_CONST,__objc_protolist` slot `0x19338B0`, and `__DATA,__objc_protorefs` slot `0x1AD1218`). Its name pointer at `0x1A38C88` resolves to native C string **`_TtP11TwitterHome22TwitterHomeFeatureObjC_`**, i.e. the Objective-C-visible Swift protocol **`TwitterHomeFeatureObjC`** in module `TwitterHome`. The method list resides in the protocol's **required instance methods** field (`protocol + 0x18`), not in a class implementation.

| Protocol method index | Objective-C selector | SQLite field address | Native `imp` delta |
|---:|---|---|---:|
| 0 | `homeFeaturesConfigurationWithAccount:networkQualityProvider:timelineVariant:` | `0x141D2C8` | 0 |
| 1 | `homeTimelineContainerViewControllerWithAccount:homeTimeline:countryFilteredTimeline:latestTimeline:rankedFollowingTimeline:titleViewPlugins:barButtonItemPlugins:` | `0x141D2D4` | 0 |
| 2 | `homeTimelineItemsViewControllerWithAccount:timeline:` | `0x141D2E0` | 0 |
| 3 | `urtHomeTimelineStreamFactoryWithApplicationLink:homeConfiguration:` | `0x141D2EC` | 0 |
| 4 | `pinnedTimelinesRepositoryWithAccount:` | `0x141D2F8` | 0 |
| 5 | `pinnedTimelineViewControllerWithAccount:pinnedTimeline:` | `0x141D304` | 0 |
| 6 | `editPinnedTimelinesViewControllerWithAccount:` | `0x141D310` | 0 |
| 7 | `tabManagementSheetViewControllerWithAccount:scribePage:scribeSection:` | `0x141D31C` | 0 |

**Implication:** OX-051's concern is resolved more precisely: these home-related selectors are a **factory interface contract** exposed via `TwitterHomeFeatureObjC`. The concrete conforming class, method implementation(s), call sites, row-adapter factory and relation to `T1StatusTableRowAdapter` remain **unresolved**. Do **not** claim the protocol itself supplies execution code or that these selectors establish standard home-timeline cell selection.

**Reproduction:** inspect three-word relative entries with `struct.unpack_from('<IIi', macho, 0x141D2C0 + 12*i)` for `i=0..7`; inspect `llvm-objdump --macho --dyld-info T1Twitter` for slots `0x1A38C98`, `0x19338B0`, `0x1AD1218`; read zero-terminated name bytes at `0x143C710`. Cross-check SQLite `select selector,imp,entry_index from objc_methods where list_address=21091000 order by entry_index`.

Next: find conforming implementation(s) / Swift bridge for `TwitterHomeFeatureObjC` via ObjC class protocol lists and Swift conformance metadata; follow concrete `homeTimelineItemsViewControllerWithAccount:timeline:` implementation and its data-source adapter selection.

No app source/main/version changes. No live iPhone results implied.


## OX-053 — Home factory selectors have no concrete ObjC method entries in T1Twitter index (2026-10-20)

Primary inputs: user-supplied official X v12.25 `T1Twitter` Mach-O and `scarlet_macho(1).sqlite`. This pass used read-only SQLite queries and native Mach-O symbol listings, not an iPhone runtime test.

A complete lookup of the exact selector `homeTimelineItemsViewControllerWithAccount:timeline:` in the supplied SQLite `objc_methods` table returns **one** row: `binary_id=1`, `list_address=21091000 (0x141D2B8)`, `entry_index=2`, `imp=21091040 (0x141D2E0)`. The full selector `homeTimelineContainerViewControllerWithAccount:homeTimeline:countryFilteredTimeline:latestTimeline:rankedFollowingTimeline:titleViewPlugins:barButtonItemPlugins:` also returns **one** row, in the same list at index 1, with `imp=0x141D2D4`. OX-052 established this list is the required-instance declaration list for the Swift-exposed ObjC protocol `TwitterHomeFeatureObjC` and the 12-byte entries' implementation deltas are zero. Hence **the available ObjC method index supplies no concrete implementation for either selector**. This is a statement about the index's coverage, **not** proof that X has no implementation: Swift method dispatch, separate binaries and optimized/stripped code are possible explanations still needing verification.

The same native T1Twitter symbol table independently includes concrete Objective-C class symbols:

| Symbol | VM address |
|---|---:|
| `_OBJC_CLASS_$_TwitterHomeFeature` | `0x1B56120` |
| `_OBJC_CLASS_$_TwitterHomeFeatures` | `0x1B56D28` |
| `_OBJC_METACLASS_$_TwitterHomeFeature` | `0x1BBBD38` |
| `_OBJC_METACLASS_$_TwitterHomeFeatures` | `0x1BBC848` |

**Naming alone does not establish** that `TwitterHomeFeature` or `TwitterHomeFeatures` adopts `TwitterHomeFeatureObjC`, implements these factory methods, or selects `T1StatusTableRowAdapter`. The next step is to decode class `class_ro_t` protocol lists and relevant Swift conformance metadata, and inspect the other IPA binary records for concrete factory implementations. Keep OX-050's adapter-to-cell path explicitly conditional until that link is verified.

Reproduce:
```sh
python3 - <<'PY'
import sqlite3
con=sqlite3.connect('scarlet_macho(1).sqlite')
for sel in ('homeTimelineItemsViewControllerWithAccount:timeline:', 'homeTimelineContainerViewControllerWithAccount:homeTimeline:countryFilteredTimeline:latestTimeline:rankedFollowingTimeline:titleViewPlugins:barButtonItemPlugins:'):
    print(sel,con.execute('SELECT binary_id,imp,list_address,entry_index FROM objc_methods WHERE selector=?',(sel,)).fetchall())
PY
llvm-objdump --macho --syms T1Twitter | grep 'OBJC_.*TwitterHomeFeature'
```

Only diagnostic documentation on `develop` changed. No app code, version, `main` or live-device measurements.


## OX-054 — TwitterHomeFeature(s) do not directly declare ObjC protocols in class_ro_t (2026-10-20)

Primary evidence: user-provided official X v12.25 `T1Twitter` original Mach-O, read-only. Confirmed class symbol virtual addresses from OX-053. The class metadata uses chained fixup encoded pointers; addresses listed here are unslid Mach-O virtual addresses, NOT process addresses.

| Objective-C class | class_t VA | class_t data word | decoded class_ro_t VA | class_ro_t `baseProtocols` (offset +0x28) |
|---|---|---|---|---|
| `TwitterHomeFeature` | `0x1B56120` | `0x40000001B560C2` | `0x1B560C0` | **0** |
| `TwitterHomeFeatures` | `0x1B56D28` | `0x40000001B56CCA` | `0x1B56CC8` | **0** |

For both class records, the `class_t` word at offset `+0x20` has low flag bits 2 and points to `class_ro_t` after masking pointer metadata and class data flags. At each resolved `class_ro_t`, the `baseProtocols` field (+0x28 in this ObjC ABI) is **zero**. Thus **neither class directly lists any Objective-C protocol adoption** in its native class metadata. Specifically, OX-053's name-based candidates have **no directly recorded adoption of `TwitterHomeFeatureObjC`** at these class_ro_t fields.

This conclusion is deliberately narrow: a zero direct protocol list does **not** exclude protocol adoption through a superclass, dynamically added protocols, Swift-side conformances, cross-module implementations, or methods forwarded at runtime. Nor does it prove these classes are unrelated to the home timeline; each has other metadata/methods that have not been fully followed. The concrete implementation of `homeTimelineItemsViewControllerWithAccount:timeline:` and the home-data-source → `T1StatusTableRowAdapter` edge are still unresolved. Do not treat either class as a confirmed ObjC protocol implementer.

Reproduce with 64-bit little-endian reads (the file's `__DATA` class records are directly mapped at the quoted VAs for this image):
```python
import struct
b = open('T1Twitter','rb').read()
for class_va in (0x1B56120, 0x1B56D28):
    data_word = struct.unpack_from('<Q',b,class_va+0x20)[0]
    ro_va = (data_word & 0xFFFFFFFFF) & ~7
    proto_word = struct.unpack_from('<Q',b,ro_va+0x28)[0]
    print(hex(class_va),hex(data_word),hex(ro_va),hex(proto_word))
```

This confirms **native direct protocol metadata only**. No app source, executable, version or `main` branch change; no iPhone runtime validation.


## OX-055 — TwitterHomeFeature and TwitterHomeFeatures are direct NSObject subclasses (2026-10-20)

Primary evidence: supplied official X v12.25 `T1Twitter` Mach-O, read-only. Inspected native ObjC `class_t` records at `0x1B56120` / `0x1B56D28` and validated the chained-bind resolution independently with `llvm-objdump --macho --dyld-info`. The on-disk superclass pointer is a chained **bind**, not an ordinary unslid pointer; decode it using dyld binding info rather than interpreting its raw integer as a VM address.

| Class | class_t VM | superclass bind slot | dyld-resolved superclass | class_ro_t baseMethods list | list count | class_ro_t baseProtocols |
|---|---|---|---|---|---:|---:|
| `TwitterHomeFeature` | `0x1B56120` | `0x1B56128` | `_OBJC_CLASS_$_NSObject` (libobjc) | `0x13810E0` | 2 | 0 |
| `TwitterHomeFeatures` | `0x1B56D28` | `0x1B56D30` | `_OBJC_CLASS_$_NSObject` (libobjc) | `0x1381100` | 90 | 0 |

Both superclass slots contain the same chained bind value `0x8010000000003A54`; dyld info explicitly identifies `_OBJC_CLASS_$_NSObject`. Class_ro_t direct protocol fields were separately shown zero in OX-054. The native relative method-list headers at `0x13810E0` and `0x1381100` are respectively `(0x8000000C,2)` and `(0x8000000C,90)`. The counts refer to the **instance method metadata** of these two classes; they do not indicate which timeline UI code uses them.

**Narrow implication:** Their Objective-C superclass chains go directly to NSObject, so **inheritance through an intermediate Objective-C superclass cannot explain** adoption of `TwitterHomeFeatureObjC` for these two named classes. Their direct protocol lists are empty. This is **not** a proof that neither plays a role in home features or that no Swift-side bridge/adoption exists elsewhere. In particular, the 90-method `TwitterHomeFeatures` metadata merits selector-level inspection, and actual implementations may be in other classes/modules.

Reproduce:
```sh
llvm-objdump --macho --dyld-info T1Twitter | grep -E '0x1B56128 |0x1B56D30 '
python3 - <<'PY'
import struct
b=open('T1Twitter','rb').read()
for cls in (0x1B56120,0x1B56D28):
    superclass=struct.unpack_from('<Q',b,cls+8)[0]
    ro=(struct.unpack_from('<Q',b,cls+0x20)[0]&0xfffffffff)&~7
    methods=struct.unpack_from('<Q',b,ro+0x20)[0]&0xfffffffff
    proto=struct.unpack_from('<Q',b,ro+0x28)[0]
    hdr=struct.unpack_from('<II',b,methods)
    print(hex(cls),hex(superclass),hex(ro),hex(methods),hdr,hex(proto))
PY
```

Next: decode `TwitterHomeFeatures`' 90 native instance-method entries and other relevant classes' method/Swift metadata; seek a concrete `TwitterHomeFeatureObjC` implementation or home timeline view-controller factory call, and connect to `T1StatusTableRowAdapter` only with verified call/dataflow evidence. No app code, `main`, or version changes and no SE runtime result.


## OX-056 — TwitterHomeFeatures 90-method list is feature configuration, not home view-controller factory (2026-10-20)

Primary source: user-provided official X v12.25 `T1Twitter` Mach-O, read-only. Parsed both classes' native 12-byte relative Objective-C instance method-list entries and dereferenced selector slots from original chained-fixup pointer values (low 36 bits). For `TwitterHomeFeatures`, instance method-list VM `0x1381100` header `0x8000000C, 90` yields **90 selector names and 90 nonzero executable IMP addresses** in the range `0x124C608..0x124F568`. For `TwitterHomeFeature`, list `0x13810E0` has only `init` (IMP `0x123DF58`) and `.cxx_destruct` (IMP `0x123DF78`).

Representative `TwitterHomeFeatures` entries (exact list indices and unslid native IMPs):

| Index | Selector | IMP |
|---:|---|---:|
| 0 | `homeTimelineMinimumAdSpacing` | `0x124C608` |
| 11 | `showsDiscoverPeopleNavButtonForAccount:` | `0x124CF18` |
| 14 | `maxSeenIDsInHomeTimelineRequest` | `0x124D068` |
| 27 | `isDeferLoadingInactiveTimelinesEnabled` | `0x124D69C` |
| 31 | `isMemoryReliefClearCachedDisplayTextEnabled` | `0x124D884` |
| 52 | `threadedHomeConversationModuleRenderingEnabled` | `0x124E2E0` |
| 57 | `isViewportAwareLoadingEnabled` | `0x124E518` |
| 67 | `coldStartLoadingDeferralSeconds` | `0x124E9A8` |
| 80 | `homeTimelineForegroundRefreshMinBackgroundSeconds` | `0x124F000` |
| 87 | `initWithFeatureSwitches:` | `0x124F4FC` |
| 88 | `init` | `0x124F52C` |
| 89 | `.cxx_destruct` | `0x124F568` |

A complete 90-entry selector-name scan finds **no** `homeTimelineItemsViewControllerWithAccount:timeline:`, `homeTimelineContainerViewControllerWithAccount:...`, `statusCellClass`, or obvious view-controller construction selector in this **instance method list**. Most selectors expose home feed behavior flags, ad spacing, cache/prefetch/de-duplication options, cold start thresholds and premium navigation settings. Therefore the concrete role supported by this native method list is **feature configuration**, not a directly visible Objective-C home timeline view-controller factory. This does not exclude implementation through separate Swift functions, class methods, categories or other binaries, and does not disprove indirect involvement of the class in home timeline creation.

**Interpretation updated from OX-055:** The 90-method count was a lead, not evidence of 90 timeline builders. That candidate's instance selector scan is now exhausted. Search instead for concrete `TwitterHomeFeatureObjC` implementers and home-specific factories in the other Mach-O binaries and Swift metadata, while maintaining the distinction between protocol declarations (OX-052), feature settings (OX-056), and confirmed standard adapter→cell chain (OX-050).

Reproduction with original on-disk bytes:
```python
import struct
b=open('T1Twitter','rb').read()
for list_va,count in ((0x13810e0,2),(0x1381100,90)):
    flags,n=struct.unpack_from('<II',b,list_va)
    assert n==count and (flags&0xffff)==0xC
    for i in range(count):
        entry=list_va+8+12*i
        name_delta,types_delta,imp_delta=struct.unpack_from('<iii',b,entry)
        selref=entry+name_delta
        raw=struct.unpack_from('<Q',b,selref)[0]
        selector_va=raw&0xfffffffff
        selector=b[selector_va:].split(b'\\0',1)[0].decode('utf8','replace')
        print(i,selector,hex(entry+8+imp_delta))
```

No source change to app, no version change, no `main` change, no device measurements.


## OX-057 — Cross-binary string/index coverage for TwitterHomeFeatureObjC (2026-10-20)

Sources: user-supplied official X v12.25 IPA `com.atebits.Tweetie2_12.25_und3fined(1).ipa`, Mach-O index `scarlet_macho(1).sqlite`, read-only. **Scope limited to exact symbol/UTF-8 byte searches, not comprehensive Swift metadata decoding or code/dataflow analysis.**

**Indexer coverage:** SQLite `binaries` currently lists only two records: `T1Twitter` (binary_id=1, 33,287,408 bytes) and `XAppLibraries` (binary_id=2, 124,141,728 bytes). Thus queries of this DB are **not** an exhaustive scan of all IPA frameworks. The IPA also contains `Payload/Twitter.app/Frameworks/XServiceLibraries.framework/XServiceLibraries` (86,030,256 bytes); it is absent from the supplied index.

**SQLite cross-binary check:** Searching indexed `strings.text`, `symbols.name`, and `objc_methods.selector` for `TwitterHomeFeatureObjC` produces the known Swift protocol-name string in T1Twitter only; there is no named occurrence in indexed XAppLibraries. `homeTimelineItemsViewControllerWithAccount:timeline:` also has the previously described single indexed ObjC method entry in T1Twitter's protocol list, and no indexed XAppLibraries counterpart. Absence of an exact string in the index **cannot rule out** stripped symbols, indirect calls, or type descriptors not indexed by these tables.

**Direct IPA binary check:** Opened `XServiceLibraries` directly from the original IPA ZIP and searched its 86,030,256 uncompressed bytes for exact UTF-8 strings. Counts are zero for all four searches:

| Exact byte sequence | Occurrences in XServiceLibraries |
|---|---:|
| `TwitterHomeFeatureObjC` | 0 |
| `homeTimelineItemsViewControllerWithAccount:timeline:` | 0 |
| `T1StatusTableRowAdapter` | 0 |
| `TwitterHomeFeature` | 0 |

This narrows the **literal-name** search, but it is **not evidence** that no relevant implementation exists in XServiceLibraries, that the two classes identified in OX-053 conform to the ObjC protocol, or that home timeline uses the standard row adapter. Swift metadata names may be encoded differently, other IPA binaries may be involved, and methods can be compiled without retaining these strings.

**Next:** rather than repeating selector-name searches, decode the native Swift protocol conformance descriptors / ObjC protocol reference lists for `TwitterHomeFeatureObjC` in T1Twitter, and inspect home timeline item controller construction/data-source call sites. Keep adapter-to-home linkage unresolved pending concrete evidence.

Reproduce:
```python
import sqlite3,zipfile
db=sqlite3.connect('scarlet_macho(1).sqlite')
print(db.execute('SELECT id,name,size FROM binaries ORDER BY id').fetchall())
for table,col in [('strings','text'),('symbols','name'),('objc_methods','selector')]:
    print(table,db.execute(f'SELECT binary_id FROM {table} WHERE {col} LIKE ? GROUP BY binary_id',('%TwitterHomeFeatureObjC%',)).fetchall())
with zipfile.ZipFile('com.atebits.Tweetie2_12.25_und3fined(1).ipa') as z:
    binary=z.read('Payload/Twitter.app/Frameworks/XServiceLibraries.framework/XServiceLibraries')
    for needle in (b'TwitterHomeFeatureObjC',b'homeTimelineItemsViewControllerWithAccount:timeline:',b'T1StatusTableRowAdapter',b'TwitterHomeFeature'):
        print(needle.decode(),binary.count(needle))
```

Documentation-only commit to SCARLET-X `develop`; no source code, `main`, version or device changes.


## OX-058 — Decode Swift protocol conformance section boundaries before assigning home ownership (2026-10-20)

Primary source: user-supplied X v12.25 `T1Twitter` Mach-O (SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`). All measurements below are from read-only native Mach-O bytes, with section locations cross-checked against `llvm-objdump --macho --private-headers`.

**Swift reflection/conformance sections identified:**

| section | VM start | byte length | 4-byte relative pointer records |
|---|---|---:|---:|
| `__TEXT,__swift5_proto` | `0x17BE434` | `0x295C` | **2647** |
| `__TEXT,__swift5_types` | `0x17C0D90` | `0x2D84` | 2913 (possible type metadata references, **not** conformance count) |
| `__TEXT,__swift5_protos` | `0x17E58C8` | `0x380` | 224 (possible protocol descriptor references, **not** adoption count) |

For each of the 2647 entries in `__swift5_proto`, interpreting the signed 32-bit relative offset from its own entry address yields **2619 unique target addresses** with minimum **`0x1455C30`** and maximum **`0x149E824`**. These are Swift **protocol-conformance descriptor candidate locations**, *not* concrete Objective-C method IMP addresses. For illustration, entry `0x17BE434` has offset `+0x4306F1` and resolves to `0x1458978`; its 16-byte conformance descriptor begins with four native words `0x004306F1, 0x00294CF8, 0, 0x000300C0`. Entry `0x17BE438` resolves to `0x1455C30` with words `0x00430799, 0x00297A40, 0, 0x000300C0`.

**Constraint:** These Swift ABI conformance entries **cannot be equated directly** with the separate Objective-C `TwitterHomeFeatureObjC` protocol list found in OX-052. In particular, no named Swift conformer to `TwitterHomeFeatureObjC`, no concrete implementation of `homeTimelineItemsViewControllerWithAccount:timeline:`, and no home timeline → `T1StatusTableRowAdapter` edge were identified in this step. Resolving a Swift descriptor requires decoding its protocol reference (including indirect/objective-C reference forms), its type reference kind, and the associated type/context metadata; counts and address proximity alone are not evidence of adoption.

Reproduce:
```sh
llvm-objdump --macho --private-headers T1Twitter | grep -A9 -E 'sectname __swift5_proto$|sectname __swift5_types$|sectname __swift5_protos$'
python3 - <<'PY'
import struct
b=open('T1Twitter','rb').read()
a,n=0x17be434,0x295c//4
targets=[]
for i in range(n):
    at=a+4*i
    targets.append(at+struct.unpack_from('<i',b,at)[0])
print('entries',n,'unique',len(set(targets)),'min',hex(min(targets)),'max',hex(max(targets)))
for t in targets[:2]:
    print(hex(t),*[hex(v) for v in struct.unpack_from('<IIII',b,t)])
PY
```

Next: decode the conformance protocol and type-reference tags properly, then compare to native ObjC protocol references/factory callsites. No SCARLET-X executable, version, `main` branch, or iPhone was changed.


## OX-059 — Swift conformance protocol reference tags surveyed (2026-10-20)

Primary input: user-provided official X v12.25 `T1Twitter` Mach-O, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`. Read-only binary pass. Examined all **2647** relative conformance references in `__TEXT,__swift5_proto` at `0x17BE434..0x17C0D90`, decoding the signed descriptor offset, the descriptor's first 32-bit protocol-reference word, and the **low two tag bits** of the relative protocol reference.

| Observed protocol-reference low-two-bit tag | Descriptor records |
|---|---:|
| `1` | **2583** |
| `0` | **64** |
| `2` / `3` | **0** |

For a descriptor at `d`, the tagged protocol-reference target was computed as `d + (int32_t)word_at(d)`; remove its two low tag bits (`& ~3`) before comparing address bases. This yields **1780 distinct masked target addresses**, spanning **`0x16F1BA4..0x1908338`**. No masked target equals any of the **previously identified** Objective-C protocol reference locations for `TwitterHomeFeatureObjC`: `0x1A38C80` (protocol structure), `0x19338B0` (protolist slot), or `0x1AD1218` (protorefs slot). None of these addresses lies within the observed target range.

**Important interpretation limitation:** Most Swift descriptor protocol references are tagged indirect forms; comparing the **address of the indirect slot** to the Objective-C protocol object address is not equivalent to resolving the slot's chained/bound pointer. This pass did **not** decode all indirect slot contents and cannot establish that `TwitterHomeFeatureObjC` is absent from the conformances. Moreover, class/category adoption, implementation in another image and Swift bridging are still distinct possibilities. No concrete home controller implementation nor a home-timeline → `T1StatusTableRowAdapter` selection path is proven.

Reproduce against the original Mach-O:
```python
import struct,collections
b=open('T1Twitter','rb').read()
s,n=0x17BE434,0x295C//4
tags=collections.Counter(); masked=set()
for i in range(n):
    a=s+4*i
    desc=a+struct.unpack_from('<i',b,a)[0]
    proto_target=desc+struct.unpack_from('<i',b,desc)[0]
    tags[proto_target&3]+=1
    masked.add(proto_target&~3)
print('tags',tags,'unique',len(masked),'range',hex(min(masked)),hex(max(masked)))
for ref in (0x1A38C80,0x19338B0,0x1AD1218):
    print(hex(ref),ref in masked)
```

Next: resolve the **indirect slot contents** and chained fixups of the Swift conformance protocol-reference targets; do not claim absence of conformance from un-dereferenced slot addresses. No app code, main branch, version or device changes.


## OX-060 — Swift conformance indirect slots resolved against native chained fixups (2026-10-20)

Primary source: user-supplied official X v12.25 `T1Twitter` Mach-O, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`. Read-only inspection of `__TEXT,__swift5_proto` and `llvm-objdump --macho --dyld-info` output. This is a **fixup-resolution pass**, not an end-to-end Swift conformance or timeline call-graph proof.

OX-059 found 2,583 conformance descriptor entries using the tagged **indirect** protocol-reference format (tag 1). These resolve to **1,729 distinct indirect pointer slots**. The original Mach-O's chained-fixup enumeration accounts for **all 1,729** slots:

| Indirect slot fixup kind | Distinct slots |
|---|---:|
| external-symbol `bind` | **1,462** |
| same-image `rebase` | **267** |
| unmatched slots | **0** |

Concrete examples:
- Conformance descriptor `0x1458978` uses indirect slot `0x1889068` (encoded word `0x8010000000003812`); dyld reports bind to `_$ss35_HasCustomAnyHashableRepresentationMp` in `libswiftCore`.
- Descriptor `0x1455C30` uses slot `0x18863C8` (encoded `0x80100000000037EB`); dyld reports bind to `_$sSYMp` in `libswiftCore`.
- Slot `0x1887480` carries encoded value `0x00100000016EE098`; dyld reports same-image rebase to `0x16EE098`.

Searching the **1,729 resolved fixup lines** yields **zero named binds** containing `TwitterHomeFeatureObjC`; none of the 267 rebase lines directly identifies the known ObjC protocol VM `0x1A38C80`. **This does not establish the absence of home-feature protocol conformance.** The 64 tag-0 direct conformances are a separate population; Swift/ObjC interoperability may use other protocol metadata forms; other IPA binaries, runtime registrations and stripped/indirect implementations remain unexamined. In particular, an ObjC-visible Swift protocol declaration (OX-052) must not be assumed to appear as a named Swift `__swift5_proto` bind in this image.

**Conclusion:** OX-059's indirect-reference dereferencing gap has been closed at the level of *dyld fixup type and resolved target* for all 1,729 unique slots. No concrete `TwitterHomeFeatureObjC` implementation or home timeline → `T1StatusTableRowAdapter` selection edge has been demonstrated.

Reproduce:
```python
import struct,re,subprocess,collections
b=open('T1Twitter','rb').read()
slots=set()
for i in range(0x295C//4):
    entry=0x17BE434+4*i
    descriptor=entry+struct.unpack_from('<i',b,entry)[0]
    off=struct.unpack_from('<i',b,descriptor)[0]
    if off&3==1: slots.add((descriptor+off)&~3)
out=subprocess.check_output(['llvm-objdump','--macho','--dyld-info','T1Twitter'],text=True)
fixups={}
for line in out.splitlines():
    m=re.search(r'0x([0-9A-Fa-f]+)\\s+0x([0-9A-Fa-f]+)\\s+(bind|rebase)\\s+',line)
    if m and int(m.group(1),16) in slots:
        fixups[int(m.group(1),16)]=(m.group(3),line)
print('slots',len(slots),'matched',len(fixups),collections.Counter(v[0] for v in fixups.values()))
print('named home binds',sum('TwitterHomeFeatureObjC' in v[1] for v in fixups.values()))
```

Next: evaluate tag-0 Swift protocol direct references and explicitly inspect ObjC protocol adoption/consumer class metadata in home-related frameworks; avoid asserting a conformer from text-match absence. No app source, version, `main`, or device changes.


## OX-061 — Decode all 64 direct Swift conformance protocol references (2026-10-20)

Primary source: supplied official X v12.25 `T1Twitter` Mach-O, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`. Read-only parsing of original `__TEXT,__swift5_proto` records; no index-only inference.

OX-059 found 64 tagged **direct** protocol references (tag 0) within 2,647 Swift conformance descriptors. Decoding each signed first-word offset, clearing two tag bits and following the resulting target to a Swift protocol `ContextDescriptor` resolves **all 64 entries to 51 distinct protocol descriptor VAs**, within `0x16F1BA4..0x171C904`. All observed descriptor flags begin with protocol kind `0x43` (low five bits = 3; flags higher bits vary). The `ContextDescriptor`'s relative name field at offset `+8` resolves to readable UTF-8 names for all 51 targets.

Examples of resolved direct protocol definitions:

| Protocol context descriptor VA | Protocol name |
|---|---|
| `0x16F1BA4` | `SessionSourceAutoplayable` |
| `0x16F3538` | `SurveyCardSelectionControl` |
| `0x1700624` | `HomeTimelineDidUpdateValueExtracting` |
| `0x170E038` | `InjectionBuilderFactory` |
| `0x170F034` | `URTTimelineModuleCarouselScribeHelper` |
| `0x1710CF8` | `AccountURTTimelineEncodingPolicyFactory` |
| `0x171C904` | `CreatorProductWebViewBehavior` |

**Result of exhaustive tag-0 name check in this image:** None of the 51 direct Swift protocol context descriptors is named `TwitterHomeFeatureObjC`. The home-related `HomeTimelineDidUpdateValueExtracting` protocol is a **distinct named declaration**, not evidence of a `TwitterHomeFeatureObjC` conformer. This resolves the **64-entry direct-reference population** left open in OX-060, but does *not* prove the absence of Objective-C protocol conformance, factory implementations in other images, or the home-timeline-to-`T1StatusTableRowAdapter` edge. ObjC-visible protocol descriptors and Swift native protocol descriptors must not be conflated.

Reproduce with original Mach-O bytes:
```python
import struct
b=open('T1Twitter','rb').read()
direct=[]
for i in range(0x295C//4):
    entry=0x17BE434+4*i
    desc=entry+struct.unpack_from('<i',b,entry)[0]
    relative=struct.unpack_from('<i',b,desc)[0]
    target=desc+relative
    if (target&3)!=0: continue
    protocol=target&~3
    name_field=protocol+8
    name_at=name_field+struct.unpack_from('<i',b,name_field)[0]
    name=b[name_at:].split(b'\\0',1)[0].decode('utf8','replace')
    direct.append((protocol,name))
print('direct entries',len(direct),'unique protocol declarations',len(set(direct)))
print('TwitterHomeFeatureObjC matches',[x for x in direct if x[1]=='TwitterHomeFeatureObjC'])
print('home-named',sorted(set(x for x in direct if 'Home' in x[1])))
```

Next: examine native Objective-C references to the `TwitterHomeFeatureObjC` protocol and any concrete consumers or cross-image implementations, or inspect `HomeTimelineDidUpdateValueExtracting` as a separate lead. Do not infer the home feed's row adapter from protocol-name similarity alone. No SCARLET-X implementation, version, `main`, or SE runtime changes.


## OX-062 — Native dyld references to TwitterHomeFeatureObjC protocol object (2026-10-20)

Primary evidence: extracted **original** official X v12.25 `T1Twitter` binary from supplied IPA `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter`; inspected with `llvm-objdump --macho --dyld-info` in a read-only pass. The protocol object address `0x1A38C80` was established independently in OX-052.

Searching the **complete dyld chained-fixup text** for the exact resolved `rebase` target `0x1A38C80` returns **two slots**:

| Slot (VM) | Section | Fixup | Resolved destination |
|---|---|---|---|
| `0x19338B0` | `__DATA_CONST,__objc_protolist` | rebase | `0x1A38C80` |
| `0x1AD1218` | `__DATA,__objc_protorefs` | rebase | `0x1A38C80` |

Both contain the encoded chained pointer `0x0010000001A38C80`. The `__objc_protolist` slot is the image's registration of the protocol metadata; the `__objc_protorefs` slot is a separate reference to the same protocol. This **does not identify the owning method, adopting class, or callsite** for the latter. The number two applies only to slots that are explicitly represented as dyld chained-fixup **rebases to this exact address within this one Mach-O**; it is not a count of all possible protocol consumers, and it does not encompass relative references, Swift metadata accessors, code instructions or other dylibs.

**What is *not* established:** There is still no verified `TwitterHomeFeatureObjC` conforming class, concrete `homeTimelineItemsViewControllerWithAccount:timeline:` implementation, or home timeline data-source → `T1StatusTableRowAdapter` selection edge. OX-052/061/060 and this fixup result must not be combined to claim that all protocol consumers have been exhaustively ruled out. The native class/protocol list adoption scan across all relevant images and the code xrefs to `0x1AD1218` are future work.

Reproduce (on the unchanged extracted binary):
```sh
llvm-objdump --macho --dyld-info T1Twitter | grep '1A38C80'
```
For an exact count, select dyld lines matching `rebase` and **resolved target** `0x1A38C80`, rather than substring matching arbitrary fields. This pass found exactly the two records above.

Documentation-only change on `develop`; no app implementation, `main`, version, or on-device actions.


## OX-063 — Concrete code xrefs to TwitterHomeFeatureObjC ObjC protoref (2026-10-20)

Primary evidence: supplied original official X v12.25 `T1Twitter` Mach-O, using full `llvm-objdump -d` and targeted disassembly. Original protocol reference slot `0x1AD1218` was verified in OX-062 to rebase to protocol object `0x1A38C80`. This search resolves an ARM64 `ADRP` followed by the matching 64-bit `LDR` offset; it is not an exhaustive dataflow/call graph across all instruction patterns.

**Two direct adjacent ADRP/LDR sites targeting the exact protoref slot** were found in disassembled `__TEXT,__text`:

| Load site | Native instructions | Subsequent use |
|---|---|---|
| `0xABDFD8..0xABDFDC` | `adrp x8, 0x1AD1000; ldr x8, [x8,#0x218]` | `str x8,[sp,#8]`; `add x2,sp,#8`; `mov x0,x19`; `mov w1,#1`; `bl 0x12B075C` at `0xABDFF0` |
| `0xABE084..0xABE088` | `adrp x8, 0x1AD1000; ldr x8, [x8,#0x218]` | `str x8,[sp,#8]`; `add x2,sp,#8`; `mov x0,x20`; `mov w1,#1`; `bl 0x12B075C` at `0xABE09C` |

Both calls check the returned `x0` with `cbnz`; the zero-return branch executes another runtime helper at `0x12B0A80`. Surrounding calls include `0x12F1260`, `0x12A6F88`, `0x129FD88`, `0x12B0414`, `0x12B0624`. Their precise roles and the owners of the two code ranges have **not** been identified, so the semantics of `0x12B075C` must not be guessed. In particular, a protocol reference passed as an argument does not demonstrate a class adopting the protocol, and it is **not evidence that the home timeline selects `T1StatusTableRowAdapter`**.

**Finding:** At least two executable instruction paths in this Mach-O use the exact `TwitterHomeFeatureObjC` Objective-C protocol reference. OX-062's two dyld fixup slots were metadata locations; the two code sites reported here are *separate actual loads* of the one `__objc_protorefs` slot. The count two is restricted to direct adjacent `ADRP x8 / LDR x8,#0x218` xrefs observed in this pass, not all possible protocol consumers, indirect data accesses or dynamic runtime uses.

Reproduce:
```sh
llvm-objdump -d --start-address=0xabdf70 --stop-address=0xabe0d0 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep '1AD1218'
```

Next: inspect `0x12B075C` helper and resolve ownership or nearby symbol boundaries around `0xABDF7C` and `0xABE018`; search Swift method metadata and associated type names before assigning home-feature semantics.

Documentation on `develop` only; no app executable, version, `main`, or real-device change.


## OX-064 — 0x12B075C is Swift conditional ObjC protocol dynamic cast (2026-10-20)

Primary input: user-supplied original official X v12.25 `T1Twitter` Mach-O, inspected locally with `llvm-objdump`. This **resolves OX-063's unidentified runtime helper**, but does not yet identify the two enclosing functions' class/Swift owners.

`0x12B075C` is inside `__TEXT,__stubs`, not a bespoke app function. Its native instruction sequence is:

```asm
0x12B075C adrp x16, 0x186F000
0x12B0760 ldr  x16, [x16,#0xA58] ; __DATA_CONST,__got VM 0x186FA58
0x12B0764 br   x16
```

The original Mach-O's `llvm-objdump --macho --dyld-info` resolves the exact `__got` slot **`0x186FA58`** as an external **bind to `libswiftCore` symbol `_swift_dynamicCastObjCProtocolConditional`**. Adjacent slot `0x186FA50` is `_swift_dynamicCastObjCClassUnconditional`, emphasizing that the symbolic identity here is specifically the **conditional Objective-C protocol cast**.

The OX-063 call sites are:

- `0xABDFF0`: `x0=x19` candidate object, `w1=1`, `x2=&stack[8]` after storing the pointer loaded from `__objc_protorefs` slot `0x1AD1218`, then call `0x12B075C`. Return `x0` is tested with `cbnz`; null-return path calls `0x12B0A80` and returns zero.
- `0xABE09C`: likewise `x0=x20`, `w1=1`, `x2=&stack[8]`, `0x12B075C` then tests result for nonzero, with a separate failure branch. In both cases the protocol reference was established in OX-062 to refer to `TwitterHomeFeatureObjC`.

**Established meaning:** Both instruction sequences attempt a Swift runtime **conditional cast of an object to the Objective-C `TwitterHomeFeatureObjC` protocol**. They are runtime *checks/use of a protocol type*, not static proof of any particular conforming class, a method implementation, or the home timeline's actual adapter. The exact higher-level function names, origins of x19/x20, and following return-value consumers are not yet known.

Reproduce:
```sh
llvm-objdump -d --start-address=0x12b0750 --stop-address=0x12b0768 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep -i '0x186FA58'
llvm-objdump -d --start-address=0xabdf90 --stop-address=0xabe0c0 T1Twitter
```

Next: resolve the boundaries and metadata ownership of functions around `0xABDF7C` and `0xABE018`, and inspect how the successful cast value is used. Source/docs-only update, no app code, version, `main` or SE device changes.


## OX-065 — TwitterHomeFeatureIdentifier is used immediately before both ObjC protocol casts (2026-10-20)

Primary evidence: user-supplied original X v12.25 `T1Twitter` Mach-O, re-extracted from the supplied IPA and inspected read-only using ARM64 `llvm-objdump` disassembly and native dyld fixups. The exact unslid addresses are from the original image; they are not runtime slide-adjusted addresses.

**Both OX-063/064 cast callsites are inside distinct native code ranges**, starting at `0xABDF7C` and `0xABE018`. Both read global slot `0x185D680` through `adrp x8,0x185D000; ldr x8,[x8,#0x680]; ldr x0,[x8]`. The original `llvm-objdump --macho --dyld-info` output identifies that `__DATA_CONST,__got` slot as a **bind to `XAppLibraries::_TFNTwitterHomeFeatureIdentifier`**. This is a concrete home-feature-identifier linkage, not a guess from method names.

| Code range | Identifier-related instructions | Conditional protocol cast | Successful result |
|---|---|---|---|
| `0xABDF7C..0xABE014` | `0xABDFA8` ADRP, `0xABDFAC` LDR GOT, `0xABDFB0` LDR `x0,[x8]`; calls `0x12A6F88` and `0x129FD88` | `0xABDFF0` → `swift_dynamicCastObjCProtocolConditional` using `TwitterHomeFeatureObjC` | nonnull `x0` branches to shared return `0xABE004`; null returns zero after helper call |
| `0xABE018..0xABE0CC` | `0xABE048` ADRP, `0xABE04C` LDR GOT, `0xABE050` LDR `x0,[x8]`; calls `0x12A6F88` and `0x129FD88` | `0xABE09C` → same conditional cast and protocol | nonnull `x0` branches to `0xABE0BC` and then tail-branches via `0x12B033C`; null returns zero |

In the first range, `x19` captures the `x0` output of call `0x129FD88` at `0xABDFC0`, is checked for null at `0xABDFD4`, then is supplied as `x0` for the protocol cast. In the second, `x20` captures `0x129FD88`'s `x0` at `0xABE064`, is checked for null at `0xABE080`, then supplied for the cast at `0xABE09C`. Thus **in both cases the cast input is the returned object from the same call**, after obtaining the `TwitterHomeFeatureIdentifier` symbol. The exact semantics of `0x129FD88`, the identity/type of the returned object, and the enclosing function's source-level names still require proof.

This strongly motivates investigating a feature-registry or dependency-resolution path; **that is a hypothesis**, not a verified implementation classification. There is still no native proof of a concrete `TwitterHomeFeatureObjC` conforming class, no home item view-controller factory IMP, and no established home data-source → `T1StatusTableRowAdapter` use.

Reproduce:
```sh
llvm-objdump -d --start-address=0xABDF7C --stop-address=0xABE0D0 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep '0x185D680 '
llvm-objdump -d --start-address=0x12A6F88 --stop-address=0x12A6F98 T1Twitter
llvm-objdump -d --start-address=0x129FD88 --stop-address=0x129FD98 T1Twitter
```

Next: resolve GOT targets of `0x12A6F88` and `0x129FD88`, and recover callers of the two functions; inspect the `XAppLibraries` identifier type/feature registration before asserting implementation class ownership. Only this diagnostic document on `develop` changed; app executable, version, `main` and iPhone remain untouched.


## OX-066 — Feature registry lookup resolves to XServiceLibraries TwitterFeatureRegistry.feature(for:) (2026-10-20)

Primary source: user-supplied official X 12.25 `T1Twitter` Mach-O, SHA-256 `1af51e57d746a81546da299e103241da9682ac397f33475defec7f6a3e6e5ccd`. Checked disassembly and dyld chained bind metadata from the original native executable, read-only.

In OX-065, `0x129FD88` was the yet-unresolved function called after loading `XAppLibraries::_TFNTwitterHomeFeatureIdentifier`, with its returned object used in the `TwitterHomeFeatureObjC` conditional cast. The stub is:

```asm
0x129FD88  adrp x16, 0x1865000
0x129FD8C  ldr  x16, [x16,#0x190]  ; GOT slot 0x1865190
0x129FD90  br   x16
```

Native `llvm-objdump --macho --dyld-info` identifies the GOT entry **`0x1865190`** as a **bind to `XServiceLibraries`** symbol `_$s14TFSTwitterCore22TwitterFeatureRegistryC7feature3forAA0cD0_pSgSS_tF`, whose Swift-mangled components represent **`TFSTwitterCore.TwitterFeatureRegistry.feature(for: String) -> optional TwitterFeature protocol existential`**. The generic observation “registry returns an object” from OX-065 can now be refined to **this concrete registry lookup**. Swift symbol decoding here identifies the called function's signature and linked module; it does not determine the returned object's runtime concrete class.

The two verified callsite paths (`0xABDF7C..` and `0xABE018..`) now have the following supported linkage:

`XAppLibraries::_TFNTwitterHomeFeatureIdentifier` → `XServiceLibraries::TwitterFeatureRegistry.feature(for:)` via GOT slot `0x1865190` → conditional ObjC protocol cast `swift_dynamicCastObjCProtocolConditional` against `TwitterHomeFeatureObjC` (OX-064).

This confirms the **feature-registry retrieval mechanism** and removes the primary uncertainty about `0x129FD88`. It does **not** establish the feature registry's concrete registration, the type of the object returned for the home identifier, implementation of home controller factories, or whether the home feed selects `T1StatusTableRowAdapter`.

Reproduce:
```sh
llvm-objdump -d --start-address=0x129fd88 --stop-address=0x129fd94 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep '0x1865190 '
llvm-objdump -d --start-address=0xabdf90 --stop-address=0xabe0b0 T1Twitter
```

Next: inspect how `TwitterHomeFeatureIdentifier` is registered and how the retrieved protocol value's successful cast is consumed, then trace actual home timeline item factory and row adapter selection. No SCARLET-X app code, version, `main` branch, or SE device changes.


## OX-067 — TwitterHomeFeatureIdentifier exported storage and its first chained rebase (2026-10-20)

Primary evidence: user-provided **official X v12.25** IPA, extracted `XAppLibraries.framework/XAppLibraries` Mach-O plus `T1Twitter` Mach-O; checked read-only with `llvm-objdump --macho --syms`, `--dyld-info`, and raw little-endian binary reads. This examines identifier storage, **not** the feature registration function or concrete implementation class.

The original `XAppLibraries` symbol table contains the defined global object `_TFNTwitterHomeFeatureIdentifier` at unslid VM **`0x5F22F88`**, in `__DATA_CONST,__const`. `T1Twitter` has the symbol as an **undefined import** and binds its GOT slot `0x185D680` to that name (as observed in OX-065). Therefore this identifier is imported across the **T1Twitter → XAppLibraries** boundary, rather than defined inside `T1Twitter`.

At `XAppLibraries` address `0x5F22F88`, the raw 8-byte value is **`0x0010000006248360`**, and native dyld chained-fixup output independently identifies a **rebase to `0x6248360`**. The next 8-byte data words at `0x5F22F90` and `0x5F22F98` are separate rebases to `0x62483E0` and `0x6248400`, respectively; they must **not** automatically be attributed to the same symbol or interpreted as one identifier structure without symbol-size/section layout evidence.

| Confirmed edge | Evidence |
|---|---|
| `T1Twitter` references `_TFNTwitterHomeFeatureIdentifier` | Undefined symbol and GOT bind slot `0x185D680` |
| `XAppLibraries` defines `_TFNTwitterHomeFeatureIdentifier` | Object symbol `0x5F22F88` |
| First stored word resolves elsewhere in `XAppLibraries` | `0x5F22F88` rebase → `0x6248360` |
| T1Twitter calls feature lookup using that identifier | OX-065/066: `TwitterFeatureRegistry.feature(for:)` |

**Limit:** The bytes at `0x6248360` are **not decoded here as a Swift String or registry key**. No mapping from identifier to registered concrete `TwitterHomeFeatureObjC` implementation has been established. A chained data rebase by itself does **not** prove a class registration, allocation, or home timeline adapter selection. Decoding these data records requires checking their native section layout and any actual registration/use callsites, rather than interpreting nearby bytes by eye.

Reproduce (original Mach-O files):
```sh
llvm-objdump --macho --syms XAppLibraries | grep '_TFNTwitterHomeFeatureIdentifier'
llvm-objdump --macho --syms T1Twitter | grep '_TFNTwitterHomeFeatureIdentifier'
llvm-objdump --macho --dyld-info XAppLibraries | grep '0x5F22F88 '
llvm-objdump --macho --dyld-info T1Twitter | grep '0x185D680 '
python3 - <<'PY'
import struct
b=open('XAppLibraries','rb').read()
for addr in (0x5F22F88,0x5F22F90,0x5F22F98):
 print(hex(addr), hex(struct.unpack_from('<Q',b,addr)[0]))
PY
```

Next: establish the identifier's exact data type/extent from XAppLibraries native metadata, then seek a verified feature-registry registration callsite and concrete implementation. The home timeline → `T1StatusTableRowAdapter` relation remains unproven. Documentation-only change to `develop`; no SCARLET-X app code, version, `main`, or iPhone changes.


## OX-068 — TwitterHomeFeatureIdentifier resolves to CFString "com.twitter.home" (2026-10-20)

Primary evidence: user-supplied official X v12.25 `XAppLibraries.framework/XAppLibraries` extracted from original IPA, read-only, and independent native `llvm-objdump --macho --dyld-info` corroboration. OX-067 established the symbol `_TFNTwitterHomeFeatureIdentifier` at `0x5F22F88` in `__DATA_CONST,__const`, and its first pointer's chained rebase to `0x6248360`.

**Resolved data type and value:** `0x6248360` lies in `__DATA_CONST,__cfstring`; the first word (`0x8020000000002F73`) is a dyld chained bind to CoreFoundation `___CFConstantStringClassReference`. This is a native **CFString constant object**, not a class-registration record. Its 32-byte payload is:

| CFString slot | VM | On-disk 64-bit word / decoded value |
|---|---|---|
| isa/class | `0x6248360` | `0x8020000000002F73` → bind `___CFConstantStringClassReference` |
| flags | `0x6248368` | `0x7C8` |
| character data pointer | `0x6248370` | `0x00200000054AADDE` → rebase `0x54AADDE` |
| length | `0x6248378` | `0x10` = **16** |

At `XAppLibraries` VM `0x54AADDE` the original bytes are `63 6f 6d 2e 74 77 69 74 74 65 72 2e 68 6f 6d 65 00`, i.e. null-terminated ASCII/UTF-8 string **`com.twitter.home`** (16 characters before NUL). Both pointer rebases and the CFString class bind are explicitly present in the native chained fixup records. Therefore OX-066's registry lookup uses a defined home-feature identifier whose pointed-to CFString content is `com.twitter.home`. This is the identifier value, **not** the concrete feature implementation class and not a registration call.

**Limits:** the immediately following global symbols/CFString objects at `0x5F22F90` and `0x5F22F98` are distinct data and cannot be combined into one structure without evidence. No registration writer or concrete conforming `TwitterHomeFeatureObjC` class has been identified. No connection from normal home timeline to `T1StatusTableRowAdapter` is proven.

Reproduce:
```sh
llvm-objdump --macho --syms XAppLibraries | grep '_TFNTwitterHomeFeatureIdentifier'
llvm-objdump --macho --dyld-info XAppLibraries | grep -E '0x5F22F88 |0x6248360 |0x6248370 '
python3 - <<'PY'
import struct
b=open('XAppLibraries','rb').read()
ptr=struct.unpack_from('<Q',b,0x5F22F88)[0] & 0xFFFFFFFFF
isa,flags,chars,length=struct.unpack_from('<QQQQ',b,ptr)
char_addr=chars & 0xFFFFFFFFF
print(hex(ptr),hex(isa),hex(flags),hex(char_addr),length,b[char_addr:char_addr+length])
assert b[char_addr:char_addr+length]==b'com.twitter.home'
PY
```

Next: use the confirmed identifier string to search registration/storage callsites in the native feature-registry implementation and determine which concrete feature is registered. Diagnostic document only; no changes to SCARLET-X app code, version, `main` or iPhone SE.


## OX-069 — Home timeline runtime class landmarks alongside feature-registry discovery (2026-10-21)

Source: original user-provided **official X 12.25 IPA**, re-extracted unmodified `T1Twitter.framework/T1Twitter` and `XAppLibraries.framework/XAppLibraries`; cross-checked with the supplied `scarlet_macho(1).sqlite` symbol index. This entry identifies actual **defined runtime class symbols**, not class registration or dynamic call order.

The `T1Twitter` Mach-O symbol index contains these **defined** ObjC runtime class objects (un-slid addresses):

| Module | Class symbol | ObjC class-object address |
|---|---|---|
| T1Twitter | `_OBJC_CLASS_$_TFNTwitterHomeTimeline` | `0x1B573C0` |
| T1Twitter | `_OBJC_CLASS_$_TwitterHomeTimelineManagerProvider` | `0x1B57398` |
| T1Twitter | `_OBJC_CLASS_$_T1HomeTimelineVariantCoordinator` | `0x1B37C90` |
| T1Twitter | `_OBJC_CLASS_$_T1HomeTimelineAppNavigationTabEntry` | `0x1B008E0` |
| T1Twitter | `_OBJC_CLASS_$_T1HomeTimelineRefreshTaskProvider` | `0x1B567C0` |
| T1Twitter | `_OBJC_CLASS_$_TwitterHomeFeature` | `0x1B56120` |
| T1Twitter | `_OBJC_CLASS_$_TwitterHomeFeatures` | `0x1B56D28` |

The `XAppLibraries` Mach-O defines the distinct global `_TFNTwitterHomeFeatureIdentifier` at `0x5F22F88` (OX-067/068: CFString content `com.twitter.home`). This establishes a **cross-binary distinction**: the home feature key is defined by `XAppLibraries`, whereas multiple home-related concrete ObjC runtime class objects are defined inside `T1Twitter`.

The class names are useful **investigation landmarks only**. Their mere co-occurrence does **not** establish that `TwitterHomeFeature` is registered into `TwitterFeatureRegistry` under `com.twitter.home`, that `TFNTwitterHomeTimeline` constructs the home feed, or that any particular `T1StatusTableRowAdapter` is selected. OX-065/066 establishes lookup and protocol-cast callsites, but does not bridge registration or returned implementation.

Reproduce:
```sh
llvm-objdump --macho --syms T1Twitter | grep -E '_OBJC_CLASS_\\$_(TFNTwitterHomeTimeline|TwitterHomeTimelineManagerProvider|T1HomeTimelineVariantCoordinator|T1HomeTimelineAppNavigationTabEntry|T1HomeTimelineRefreshTaskProvider|TwitterHomeFeature|TwitterHomeFeatures)'
llvm-objdump --macho --syms XAppLibraries | grep '_TFNTwitterHomeFeatureIdentifier'
```

Next: inspect exact ObjC metaclass/class method-list and native function cross-references for the **home timeline manager-provider/feature** candidates, then seek an actual registration/factory edge. Do not treat names or proximity as a verified execution path. Diagnostic-only commit to `develop`; no app code, version, `main`, or SE changes.


## OX-070 — Native ObjC method-list evidence for home timeline manager provider (2026-10-21)

Primary source: unmodified official X iOS v12.25 `T1Twitter.framework/T1Twitter` Mach-O extracted from supplied IPA. The ObjC class pointers, `class_ro_t` metadata, relative method-list entries, dyld rebase pointers to selector C-strings, and disassembled executable methods were read directly from this Mach-O; none of the following class-method associations is inferred from symbol proximity.

The class object `_OBJC_CLASS_$_TwitterHomeTimelineManagerProvider` is `0x1B57398`. Its `class_ro_t` is at `0x1A85C50`, with instance base-method list at `0x13F28E0`. List header `0x8000000C` (12-byte relative entries) and **count 1**. The single entry resolves via selector-reference slot `0x1ACDAC8` to `timelineManagerForAccount:`, with native implementation address **`0x1253BA8`**.

The `_OBJC_CLASS_$_TFNTwitterHomeTimeline` class object at `0x1B573C0` points to `class_ro_t` at `0x1A85EE0`; its instance base-method list at `0x13F1220` also uses relative 12-byte entries and has **34 entries**. Examples recovered directly from that list:

| Ordinal | Selector | Implementation address |
|---|---|---|
| 0 | `initWithAccount:streamFactory:` | `0x1253C14` |
| 1 | `init` | `0x12557C4` |
| 2 | `dealloc` | `0x1253D00` |
| 3 | `hasUnreadItems` | `0x1253DE4` |
| 4 | `setStream:` | `0x1253E20` |
| 5 | `deserializeStream` | `0x1253F50` |
| 6 | `performRefreshWithSource:pushToHomeTweetId:` | `0x1254148` |
| 7 | `refreshWithSource:pushToHomeTweetId:completion:` | `0x1254424` |
| 8 | `refreshWithSource:completion:` | `0x12545F4` |

For comparison, the `TwitterHomeFeature` class object at `0x1B56120` leads to `class_ro_t` `0x1B560C0` and base-method list `0x13810E0`: **2 entries**, `init` → `0x123DF58`, `.cxx_destruct` → `0x123DF78`. The `TwitterHomeFeatures` class object's instance base-method list at `0x1381100` contains **90 entries**; the list count alone does not assign factory semantics. These counts refer to **direct instance base-method lists** and are not the complete inherited/class/metaclass method sets.

The first disassembly of provider method `0x1253BA8` confirms this is executable native code, not an index field mistaken for an IMP. It takes the account parameter in `x2`, retains/releases it, loads an imported pointer through `adrp x8,0x1AD2000; ldr x20,[x8,#0x8A8]` (slot `0x1AD28A8`), calls imported stubs `0x12B02F4` and `0x12FB6C0`, then returns the result. The exact symbol binds and semantic target of the call **have not yet been identified**. The adjacent timeline initializer at `0x1253C14` is **not proof** the provider calls it (no direct branch to it appears in the first provider method disassembly).

**Scope and limits:** This establishes real runtime methods for investigating the home timeline manager, rather than merely class-name landmarks (OX-069). It does **not** establish that `TwitterFeatureRegistry.feature(for: "com.twitter.home")` returns `TwitterHomeFeature`, that this provider is reached from the home controller factory, or that the home timeline uses `T1StatusTableRowAdapter`.

Reproduce:
```sh
llvm-objdump -d --start-address=0x1253ba8 --stop-address=0x1253bf4 T1Twitter
# Decode class_ro_t and 12-byte relative entries from the unslid addresses
# above, resolve selector-reference pointers with Mach-O chained rebase data.
```

Next: resolve imported GOT address `0x1AD28A8` and the symbols behind the provider's calls `0x12B02F4` / `0x12FB6C0`, then inspect `TFNTwitterHomeTimeline initWithAccount:streamFactory:` and callers. Documentation only, `develop`; no app changes or SE operations.


## OX-071 — Home timeline manager provider allocates TFNTwitterTimelineManager (2026-10-21)

Primary source: unmodified `T1Twitter.framework/T1Twitter` from user-provided official X v12.25 IPA. Inspected actual ARM64 disassembly, Mach-O symbol table and dyld chained fixup entries.

The sole direct instance method of `TwitterHomeTimelineManagerProvider`, `timelineManagerForAccount:` (IMP **`0x1253BA8`**, OX-070), performs:

```asm
0x1253BB4  mov x19, x2                ; account
0x1253BB8  adrp x8, 0x1AD2000
0x1253BBC  ldr x20, [x8,#0x8A8]     ; ObjC classref slot 0x1AD28A8
0x1253BC0  mov x0, x2
0x1253BC4  bl  0x12B0420           ; object retain stub
0x1253BC8  mov x0, x20             ; class reference
0x1253BCC  bl  0x12B02F4           ; objc_alloc
0x1253BD0  mov x2, x19             ; account parameter
0x1253BD4  bl  0x12FB6C0           ; objc_msgSend with initWithAccount: selector
0x1253BD8  mov x20, x0             ; initializer result
0x1253BDC  mov x0, x19
0x1253BE0  bl  0x12B0414           ; object release stub
0x1253BE4  mov x0, x20             ; return initialized object
0x1253BF0  b   0x12B033C           ; autorelease-return-value stub (target semantics to verify separately)
```

Exact dyld and symbol resolutions:

- `0x1AD28A8` is an `__objc_classrefs` rebase to **`0x1B57460`**, a defined `T1Twitter` symbol **`_OBJC_CLASS_$_TFNTwitterTimelineManager`**.
- `0x12B02F4` is a three-instruction external stub using GOT slot `0x186DA50`, native dyld bind **`libobjc::_objc_alloc`**.
- `0x12FB6C0` is an ObjC message stub loading selector reference `0x1AA6F78`. That selector ref rebases to C string at `0x1612BC0`: **`initWithAccount:`**. Its dispatch GOT slot `0x186DAD8` binds **`libobjc::_objc_msgSend`**.
- These together establish the native allocation and initializer message, passing the account object as argument, and returning the initialized manager. Importantly, `TFNTwitterTimelineManager` is **distinct** from the `TFNTwitterHomeTimeline` class whose initializer `initWithAccount:streamFactory:` was inventoried in OX-070.

**Verified native flow:** `TwitterHomeTimelineManagerProvider.timelineManagerForAccount:` → `objc_alloc(TFNTwitterTimelineManager)` → `-[TFNTwitterTimelineManager initWithAccount:]` → returned manager instance.

**Not established:** a runtime call from the home controller/feature registry into this provider, exact initializer internals, or an ordinary home timeline cell adapter route. Class ownership is based on ObjC method metadata, not inferred from nearby symbols. Next: decode actual `TFNTwitterTimelineManager` initializer method entry/IMP, then trace its native calls and/or callers of `timelineManagerForAccount:`.

Reproduce:
```sh
llvm-objdump -d --start-address=0x1253ba8 --stop-address=0x1253bf4 T1Twitter
llvm-objdump -d --start-address=0x12b02f4 --stop-address=0x12b0300 T1Twitter
llvm-objdump -d --start-address=0x12fb6c0 --stop-address=0x12fb6d4 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep -E '0x1AD28A8 |0x186DA50 |0x186DAD8 |0x1AA6F78 '
llvm-objdump --macho --syms T1Twitter | grep '0x1b57460\\|1b57460'
```

Only diagnostic documentation updated on `develop`; no changes to SCARLET-X app, version, `main` or iPhone SE.


## OX-072 — TFNTwitterTimelineManager initialization requests two home timeline variants (2026-10-21)

Primary source: original official X 12.25 IPA `T1Twitter.framework/T1Twitter` (unmodified), using native ARM64 `llvm-objdump` and the Objective-C 12-byte relative method list at `0x13F1BA8`. The class `TFNTwitterTimelineManager` ObjC object is `0x1B57460`, with `class_ro_t` `0x1A86288`. Its direct instance base-method list header has `entsizeAndFlags=0x8000000C`, **17 methods**.

Verified selected selectors and IMPs from the actual ObjC method list:

| Index | Selector | IMP |
|---|---|---|
| 0 | `homeTimelineForVariant:` | `0x124C244` |
| 1 | `initWithAccount:` | `0x12557EC` |
| 5 | `homeRankedFollowingTimeline` | `0x1255AAC` |
| 6 | `homeCountryFilteredTimeline` | `0x1255B4C` |
| 7 | `homeTopicFilteredTimeline` | `0x1255C28` |
| 8 | `refreshHomeTimelineWithSource:` | `0x1255D04` |
| 9 | `refreshSecondaryTimelinesWithSource:` | `0x1255D58` |
| 10 | `refreshTimelinesWithSource:excludingTimelines:` | `0x1255E08` |
| 12 | `homeTimeline` | `0x1256374` |
| 13 | `homeLatestTimeline` | `0x125637C` |

**Initializer `-[TFNTwitterTimelineManager initWithAccount:]` at `0x12557EC`:**

- Retains incoming account (`x2`), calls superclass `init` via `objc_msgSendSuper2` at `0x12B03CC`, and initializes/stores account into `self+0x40` using `0x12B0498`.
- Loads the actual ObjC class reference at `0x1BF8DF0`, which points to **`_OBJC_CLASS_$_TFNTwitterTimelineManager` at `0x1B57460`**.
- Calls ObjC message stub `0x12F8FC0`, whose `x1` selector ref `0x1AA65B8` resolves to **`homeTimelineForAccount:`**, passing account in `x2`. Stores returned retained object at **`self+0x30`** (ARM64 `str x0,[x20,#0x30]` at `0x125585C`).
- Calls ObjC message stub `0x12F8EA0`, selector ref `0x1AA6570` resolves to **`homeLatestTimelineForAccount:`**, also passing account in `x2`. Stores returned retained object at **`self+0x38`** (`str x0,[x20,#0x38]` at `0x1255880`).
- Subsequent `self+0x40` related helper and `0x13072C0` Boolean-style result gate the final `0x12D1800` call; **their precise semantics are not determined here**.

This establishes the **actual initialization-time dispatch**:

`TwitterHomeTimelineManagerProvider.timelineManagerForAccount:` (OX-071) → allocate/init `TFNTwitterTimelineManager` → `+[TFNTwitterTimelineManager homeTimelineForAccount:]` and `+[TFNTwitterTimelineManager homeLatestTimelineForAccount:]` (dispatch on class object) → hold distinct returned values at offsets `+0x30` and `+0x38`.

The class-method implementations reached by these selectors have **not yet been resolved** from the metaclass method-list; selector resolution proves the messages issued, not the concrete returned types. It does not yet connect the live home controller to provider usage or home row adapter selection.

Reproduce:
```sh
llvm-objdump -d --start-address=0x12557ec --stop-address=0x12558d4 T1Twitter
llvm-objdump -d --start-address=0x12f8ea0 --stop-address=0x12f8eb4 T1Twitter
llvm-objdump -d --start-address=0x12f8fc0 --stop-address=0x12f8fd4 T1Twitter
# Selector-reference slots: 0x1AA6570 → "homeLatestTimelineForAccount:",
# 0x1AA65B8 → "homeTimelineForAccount:" (dyld chained rebases).
```

Next: read TFNTwitterTimelineManager **metaclass** method list and resolve the two class factory IMPs; inspect their native allocations and timeline selection. Documentation only on `develop`. No app, version, `main`, or SE changes.


## OX-073 — TFNTwitterTimelineManager metaclass owns only timelineFactory accessors (2026-10-21)

Source: re-read original official X v12.25 `T1Twitter.framework/T1Twitter` unmodified Mach-O, native ObjC class/metaclass data, 12-byte relative method-list entries, dyld binds and ARM64 disassembly. This resolves the specific next question from OX-072: **whether the two home timeline class factory selectors are directly defined in the TFNTwitterTimelineManager metaclass base methods**.

- `_OBJC_CLASS_$_TFNTwitterTimelineManager`: VM `0x1B57460`. Its `isa` chained rebase targets **metaclass `0x1B57488`**.
- Metaclass's `class_ro_t` pointer targets **`0x1A86070`**. Its direct base-method list is **`0x13946B8`**, with header `entsizeAndFlags = 0x8000000C` and **count = 2**.
- Relative method entry 0: selector **`timelineFactory`**, native IMP **`0x1256318`**.
- Relative method entry 1: selector **`setTimelineFactory:`**, native IMP **`0x1256344`**.
- Native chained bind at metaclass superclass pointer `0x1B57490` resolves to **`libobjc::_OBJC_METACLASS_$_NSObject`**. The class superclass slot `0x1B57468` likewise binds to `libobjc::_OBJC_CLASS_$_NSObject`.

ARM64 disassembly at `0x1256318..0x1256374` shows the getter loads and retains an object from a global storage slot using `adrp/ldr`, and the setter retains the new object, swaps into the same storage slot using `str`, and releases the previous object. This establishes the **timelineFactory storage-accessor behavior**, not the stored object's implementation or timeline factory dispatch targets.

**Crucial limit / corrective nuance to OX-072:** Although `-[TFNTwitterTimelineManager initWithAccount:]` issues ObjC **class messages** with selectors `homeTimelineForAccount:` and `homeLatestTimelineForAccount:` (OX-072), **neither selector is directly present in this metaclass's base-method list**. Thus OX-072's wording must not be read as a verified direct implementation of either factory on the base metaclass. Potential ObjC categories or dynamic resolution still require investigation; with NSObject as the direct superclass, the two selectors cannot simply be attributed to TFNTwitterTimelineManager's direct base class-method entries. The exact runtime implementations and returned timeline classes remain **unresolved**.

Reproduce:
```sh
llvm-objdump -d --start-address=0x1256318 --stop-address=0x1256374 T1Twitter
llvm-objdump --macho --dyld-info T1Twitter | grep '0x1B57490 '
# Metaclass 0x1B57488 → class_ro_t 0x1A86070 → base methods 0x13946B8;
# decode two 12-byte relative ObjC method entries and chained selector refs.
```

Next: inventory native `__objc_catlist` and `__objc_nlcatlist` methods to locate where the two `home*TimelineForAccount:` class factory selectors are implemented, then resolve implementation call paths. Only official-X diagnostics on `develop`; no application/SE changes.


## OX-074 — Full T1Twitter ObjC category-list scan finds no direct home factory selectors (2026-10-21)

Primary source: unmodified `Payload/Twitter.app/Frameworks/T1Twitter.framework/T1Twitter` extracted from the supplied official X 12.25 IPA. Native `__objc_catlist` and ObjC category method lists were parsed directly from Mach-O segments, with dyld chained rebases/binds for category references and relative 12-byte ObjC method-list entries.

- `T1Twitter` `__DATA_CONST,__objc_catlist` begins at **`0x1931050`**, size **`0x3F8`** = **127 eight-byte category pointers**.
- Each category descriptor's native fields `name`, `cls`, `instanceMethods`, `classMethods` were resolved, and both native instance and class method lists were decoded as 12-byte relative selector entries.
- **No decoded direct category method entry** in this binary's 127-entry `__objc_catlist` matched **`homeTimelineForAccount:`** or **`homeLatestTimelineForAccount:`**.
- Representative successful decode cross-checks: first category descriptor at **`0x19390F8`** is named `T1MediaAttachmentPlayerView`, targets external `TAVPlayerView`, and has class-method list `0x1394598` with `tfn_defaultShouldFlipForRightToLeftTransform` and `t1_playerViewWithFrame:configuration:`; second category at **`0x1939C30`** is `TwitterAnimation` targeting `TPSDeviceFeatureSwitches`. These are sanity checks that the scan actually resolves category metadata, rather than just searching symbol names.
- The strings **`homeTimelineForAccount:`** and **`homeLatestTimelineForAccount:`** are present in the binary's indexed literal strings, and the ObjC message-send sites were found in OX-072, so this category-list absence does **not** imply the selectors are unused.

**Interpretation and limits:** OX-073 found neither selector among `TFNTwitterTimelineManager`'s two direct metaclass base methods. OX-074 extends the negative to direct category method lists within **this T1Twitter image**, but it is **not a proof of no runtime implementation**. Possibilities include class methods supplied by an ObjC category in a **different Mach-O image**, dynamic method resolution/registration, an alternate receiver or dispatch behavior. `__objc_nlcatlist` and atypical list layouts, if present, still merit a separate audit. No definite home factory class or returned object is assigned.

Method: parse Mach-O `LC_SEGMENT_64` for VM-to-file mapping, native chained dyld fixup map, then enumerate each `__objc_catlist` pointer and inspect both method-list fields. Search exact selector names in successfully decoded relative selector-reference entries. This avoids misreading indexed method-list field addresses as executable IMPs.

Next: search separate loaded images (particularly `XAppLibraries` and `XServiceLibraries`) for category definitions extending `TFNTwitterTimelineManager`, and inspect the actual class receiver at OX-072 callsites. Diagnostic-only `develop`; no app, version, `main`, or SE changes.


## OX-075 — Cross-framework category-section and factory-selector survey (2026-10-21)

Primary source: user-supplied official X v12.25 IPA, freshly extracted **XAppLibraries.framework/XAppLibraries** (124,141,728 bytes) and **XServiceLibraries.framework/XServiceLibraries** (86,030,256 bytes); native `llvm-objdump --macho --section-headers`, `--objc-meta-data`, plus direct raw-byte scans.

Native section inventory:

| Image | Section | VM address | Size | Number of 8-byte entries |
|---|---|---|---|---|
| XAppLibraries | `__objc_catlist` | `0x6281C18` | `0x298` | 83 |
| XAppLibraries | `__objc_nlcatlist` | `0x6281EB0` | `0x8` | 1 |
| XServiceLibraries | `__objc_catlist` | `0x4136578` | `0x578` | 175 |
| XServiceLibraries | `__objc_catlist2` | `0x4136AF0` | `0x8` | 1 |
| XServiceLibraries | `__objc_nlcatlist` | `0x4136AF8` | `0x50` | 10 |

These are **section entry counts**, not a statement that every category descriptor/method has been successfully decoded. Raw byte scans of both complete images find **zero literal occurrences** of either exact selector string `homeTimelineForAccount:` or `homeLatestTimelineForAccount:`. In contrast, `XAppLibraries` contains two ASCII occurrences each of `TFNTwitterTimelineManager` and `TwitterHomeFeature`; `XServiceLibraries` contains zero occurrences of either. The presence of names is not enough to link them to a category or any function.

**Critical limit:** Absence of an in-image literal selector string is **not conclusive proof** that an external category does not implement or reference it: ObjC selector references may be imported/shared, and Swift/ObjC indirect runtime registrations are possible. Likewise, section inventory alone is **not a full category-method-list scan**. Therefore OX-075 does **not** extend OX-074's confirmed all-categories-negative finding to these two images. No concrete implementation of the two class-factory messages is established.

Reproduce:
```sh
llvm-objdump --macho --section-headers XAppLibraries | grep -E '__objc_(catlist|nlcatlist)'
llvm-objdump --macho --section-headers XServiceLibraries | grep -E '__objc_(catlist|catlist2|nlcatlist)'
python3 - <<'PY'
for name in ('XAppLibraries','XServiceLibraries'):
    binary = open(name,'rb').read()
    print(name,len(binary))
    for needle in (b'homeTimelineForAccount:',b'homeLatestTimelineForAccount:',
                   b'TFNTwitterTimelineManager',b'TwitterHomeFeature'):
        print(needle.decode(),binary.count(needle))
PY
```

**Next:** decode all *native* category descriptors and class-method selectors in both images (including `__objc_catlist2` / `__objc_nlcatlist`), resolve external class references with chained binds, and trace the runtime class-method dispatch used by `TFNTwitterTimelineManager`. No changes to app code/version, `main`, or SE.


## OX-076 — Full native cross-framework ObjC category class-method scan (2026-10-21)

Primary evidence: user-provided official X v12.25 IPA, unmodified extracted `XAppLibraries` and `XServiceLibraries` Mach-O executables. Unlike OX-075's section inventories and raw text searches, this pass **decoded every category descriptor and its available native class-method list** in all category sections for both images. The exact target selectors were `homeTimelineForAccount:` and `homeLatestTimelineForAccount:` (OX-072).

Technique: read 64-bit Mach-O `LC_SEGMENT_64` sections to translate unslid VM addresses to file offsets; interpret raw dyld chained rebase words by low-36-bit target; enumerate 8-byte category pointers in `__objc_catlist`, `__objc_catlist2` (when present), and `__objc_nlcatlist`; for each descriptor read `classMethods` at category +0x18; decode 12-byte relative method entries with `entsizeAndFlags = 0x8000000C`, resolve relative selector-reference slots and their rebase targets into C strings. Validate representative decoded selectors including XAppLibraries `TAF` category `storeProductViewControllerDidDismiss` and both images' `load` category methods. **No class method-list decode failed or was rejected**.

| Image | Category section entries scanned | Valid decoded class-method entries | Exact target selector matches | Unreadable class method lists |
|---|---:|---:|---:|---:|
| XAppLibraries | 83 ordinary + 1 nonlazy = 84 | **156** | **0** | **0** |
| XServiceLibraries | 175 ordinary + 1 catlist2 + 10 nonlazy = 186 | **566** | **0** | **0** |
| Total | **270** section entries | **722** | **0** | **0** |

**Interpretation:** This upgrades OX-075's string-only negative to an actual category class-method-list negative across both additional frameworks. Together with OX-074, the two home factory selectors have not been found in the decoded ordinary ObjC category class-method entries across `T1Twitter`, `XAppLibraries`, or `XServiceLibraries`; OX-073 also excluded them from `TFNTwitterTimelineManager`'s direct metaclass base method list. The selector **messages** in its `initWithAccount:` still exist (OX-072). Absence in these static lists does **not** exclude implementations in other embedded frameworks, ObjC dynamic method registration, external runtime metadata, or alternate runtime dispatch mechanisms.

Reproduction sketch:
```python
# For each Mach-O image, resolve VM-to-file offsets from LC_SEGMENT_64.
# For catptr in all __objc_catlist/__objc_catlist2/__objc_nlcatlist entries:
#   category = chained_rebase_target(catptr)
#   class_method_list = chained_rebase_target(*(category + 0x18))
#   for each 12-byte entry:
#       selref = entry_address + signed_relative_name_offset
#       selector = read_c_string(chained_rebase_target(*selref))
#       compare selector against both exact target strings
```

**Next:** Stop treating category searches in these three images as a likely route. Audit `TFNTwitterTimelineManager` class-side dynamic resolution or other embedded frameworks; alternatively trace `timelineFactory` setter writers and concrete factory instance returned at runtime, preserving the class-message/callsite distinction.

Documentation only to `develop`; no SCARLET-X app, version, `main` branch, or iPhone SE changes.


## OX-077 — Correction: two home selector messages dispatch on mutable timelineFactory storage, not a TFNTwitterTimelineManager class object (2026-10-21)

**Important correction to OX-072 and OX-073:** Verified again from the original, unmodified official X v12.25 `T1Twitter` Mach-O (ARM64 `llvm-objdump` disassembly and Mach-O section headers). Earlier OX-072 described the receiver of `homeTimelineForAccount:` and `homeLatestTimelineForAccount:` as a `TFNTwitterTimelineManager` **class** via alleged classref at `0x1BF8DF0`. That interpretation is **incorrect**. The same location is writable shared **`timelineFactory` storage** accessed by the class getter/setter, not a dyld class reference. Consequently the ObjC selector searches in OX-073 through OX-076 were aimed at the wrong receiver; their native metadata inventory/negative method-list observations remain valid only for their stated lists and must not be interpreted as excluding implementation on the **factory object's class**.

Cross-check of native instructions:

```asm
; +[TFNTwitterTimelineManager timelineFactory], IMP 0x1256318
0x1256324  adrp x8,0x1bf8000
0x1256328  ldr x19,[x8,#0xdf0]     ; storage at 0x1BF8DF0

; +[TFNTwitterTimelineManager setTimelineFactory:], IMP 0x1256344
0x1256350  mov x19,x2               ; incoming factory object
0x1256354  mov x0,x2
0x1256358  bl  0x12b0420            ; retain
0x125635c  adrp x8,0x1bf8000
0x1256360  ldr x0,[x8,#0xdf0]      ; old factory
0x1256364  str x19,[x8,#0xdf0]     ; new factory stored to 0x1BF8DF0
0x1256370  b   0x12b0414           ; release old factory

; -[TFNTwitterTimelineManager initWithAccount:], IMP 0x12557EC
0x1255840  adrp x21,0x1bf8000
0x1255844  ldr x0,[x21,#0xdf0]     ; same mutable factory object
0x1255848  mov x2,x19              ; account
0x125584c  bl  0x12f8fc0           ; message selector homeTimelineForAccount:
...
0x1255868  ldr x0,[x21,#0xdf0]     ; same mutable factory object
0x125586c  mov x2,x19              ; account
0x1255870  bl  0x12f8ea0           ; message selector homeLatestTimelineForAccount:
```

Crucial independent metadata: `llvm-objdump --macho --section-headers T1Twitter` reports **`__DATA,__bss` at `0x1BBE9C0`, size `0x3B5E0`**, hence the slot `0x1BF8DF0` lies **inside zero-initialized BSS**, not in `__objc_classrefs`. It cannot be the previous purported native chained rebase to `_OBJC_CLASS_$_TFNTwitterTimelineManager`; that purported pointer identification is **withdrawn**.

**Verified flow (corrected):** Provider allocates `TFNTwitterTimelineManager` (OX-071) → manager initializer loads **globally configured timelineFactory object** at `0x1BF8DF0` → sends the two home factory selectors to **that receiver** → holds results separately at offsets `self+0x30`, `self+0x38`. The configuration writer **`setTimelineFactory:`** stores its argument into that same global slot. The factory's concrete runtime class, configuration callsite(s), initialization timing and result types are **not yet established**.

This explains why `TFNTwitterTimelineManager` metaclass itself does not define the home factory selectors (OX-073) and why the previous three framework category scans do not close the question. Do **not** infer that a missing category implies dynamic registration is required: the receiver simply is not the manager's metaclass.

Reproduce:
```sh
llvm-objdump -d --start-address=0x12557ec --stop-address=0x125588c T1Twitter
llvm-objdump -d --start-address=0x1256318 --stop-address=0x1256374 T1Twitter
llvm-objdump --macho --section-headers T1Twitter | grep __bss
```

**Next:** find native callsites of `+[TFNTwitterTimelineManager setTimelineFactory:]` (or equivalent direct writes to BSS `0x1BF8DF0`); inspect the concrete argument construction to recover the actual factory class. Do not modify app code or device while investigating.


## OX-078 — Setter direct-call survey and factory-candidate inventory (2026-10-21)

Primary source: original user-provided official X v12.25 IPA, independently extracted original `T1Twitter.framework/T1Twitter`; the supplied `scarlet_macho` SQLite index was cross-checked with native disassembly. This deliberately narrows the task to evidence obtainable without runtime access.

- Confirmed `+[TFNTwitterTimelineManager setTimelineFactory:]` IMP **`0x1256344`** by ObjC method-list record (shared list address decimal 20530872) and native `llvm-objdump -d --start-address=0x1256318 --stop-address=0x1256374` disassembly.
- Setter sequence retains incoming object (`x2`), reads previous pointer at BSS **`0x1BF8DF0`**, overwrites the slot with incoming object, and releases previous pointer. The getter at **`0x1256318`** reads and retains this same slot (consistent with OX-077).
- Exhaustively scanned every 4-byte-aligned ARM64 instruction word in the `__TEXT` segment of this **T1Twitter** Mach-O for immediate `BL` encodings resolving to **`0x1256344`**. **0 direct BL callsites found**. This is **not** evidence the method is unused: Objective-C message sends to `setTimelineFactory:` normally dispatch via `objc_msgSend` and may be emitted in other images; this scan covers **direct BL only**.
- The binary's string/symbol index contains *defined ObjC class symbols* `T1TimelineFactory`, `T1URTOnboardingTimelineFactory`, `T1BookmarkTimelineFactory`, and Swift `URTNotificationTimelineFactory` (via `_OBJC_CLASS_$_...` in T1Twitter). These are **names/definitions only**, not validated concrete values passed to `setTimelineFactory:`. Similarly `sharedTimelineFactory` is an indexed separate ObjC selector, **not verified** as the setter argument source.

**Open:** Find selector `setTimelineFactory:` native message stub(s), resolve their `objc_msgSend` callsites and class receiver, then trace construction and concrete runtime class of the supplied argument (`x2`). Also check other embedded Mach-O images as appropriate. A raw symbol-name match or a missing direct branch cannot establish the registration pathway.

Reproduce direct-branch check using ARM64 instructions in Mach-O `__TEXT`: for word with `word >> 26 == 0b100101` (BL immediate), sign-extend low 26 bits and calculate `target = instruction_vm + 4 * imm26`; compare with `0x1256344`. The original `T1Twitter` segment covers VM `0x0..0x1854000`, file offset `0x0`.

Only diagnostics updated in `develop`; app code, build/version, main branch, iPhone SE untouched.
