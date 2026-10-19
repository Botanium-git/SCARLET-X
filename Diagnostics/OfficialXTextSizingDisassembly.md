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
