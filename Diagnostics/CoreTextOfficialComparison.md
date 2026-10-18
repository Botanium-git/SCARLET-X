# Core Text: official X versus Scarlet X controlled comparison

Status: diagnostic protocol only. Do not change production row height based on these fixtures.

## Evidence as of v1.4.166
- Scarlet X legacy height uses NSString boundingRectWithSize with UsesLineFragmentOrigin | UsesFontLeading and ceil.
- Scarlet X experimental height uses CTFramesetter / CTFrame line origins, first ascent, last descent.
- Observed 13 pt font at 328 pt width: base line metrics ascent=12.00, descent=3.51; AppleColorEmoji metrics ascent=16.25, descent=5.08.
- These measure differences INSIDE Scarlet X; they do not prove official X's output.
- The indexed T1Twitter framework refers to TFNAttributedTextModel as an external class (undefined symbol); its implementation is not established from this evidence.

## Controlled text cases
A. No emoji:
  一行目は日本語の本文です。\n二行目も日本語の本文です。\n三行目は文章だけです。
B. Emoji at first line only:
  🏇 一行目には絵文字があります。\n二行目は文章だけです。\n三行目も文章だけです。
C. Emoji in middle only:
  一行目は文章だけです。\n🏇 二行目に絵文字があります。\n三行目も文章だけです。
D. Emoji at last line only:
  一行目は文章だけです。\n二行目も文章だけです。\n🏇 三行目に絵文字があります。
E. Two emoji-bearing lines:
  🏇 一行目に絵文字があります。\n二行目は文章だけです。\n🏇 三行目に絵文字があります。

## Test requirements
1. Use the *exact same string* in official X and Scarlet X, from a test post controlled by the tester.
2. Match device, accessibility text size, app text settings, content width, viewport, and font selection. Do not assume these are already matched.
3. Compare first/last baseline position, visual line break positions, total text occupied height and next-row vertical start.
4. Keep screenshots or coordinate measurements for both apps; redact unrelated personal material.
5. Save Scarlet X diagnostic line metrics, including baselineExcess, firstAscent, lastDescent and fontNames.
6. Identify whether first/middle/last emoji position changes height; do not treat a raw Core Text-versus-legacy delta as proof of an official-X difference.
7. A mismatch must be confirmed from both screens before changing UITableView row height.

No changes to App UI, download/update system, source publishing, profile images or rendering are authorized by this document.
