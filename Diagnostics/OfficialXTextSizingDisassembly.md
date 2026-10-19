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
