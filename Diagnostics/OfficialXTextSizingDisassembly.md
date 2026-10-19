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
