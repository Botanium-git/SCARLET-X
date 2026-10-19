# OX-010 — XServiceLibraries real Objective-C class method resolution (2026-10-19)

**Source**: Original X v12.25 IPA `XServiceLibraries.framework/XServiceLibraries`, class symbols and class_ro_t decoded with chained pointer low-36-bit targets. Raw method_list_t header `0x8000000C` signifies relative entries, each 12 bytes; selector/type/IMP are signed relative offsets from their individual fields.

- TFNAttributedTextModel: class `0x4422590`; ro `0x41C2618`; method list `0x2FB10D0`; **37** instance methods, all resolved to executable ranges.
- TFNSizeThatFitsHelper: class `0x442A3A8`; ro `0x41EFD18`; method list `0x2FC75E8`; **7** instance methods, all resolved to executable ranges.

Notable class-owned methods:
| class | selector | IMP |
|---|---|---|
| TFNAttributedTextModel | initWithAttributedString: | 0xCB12F8 |
| TFNAttributedTextModel | setAttributedString: | 0xCB13E4 |
| TFNAttributedTextModel | actualSize | 0xCB1608 |
| TFNAttributedTextModel | coreTextFrame | 0xCB162C |
| TFNAttributedTextModel | lineRanges | 0xCB172C |
| TFNAttributedTextModel | contentBottomPadding | 0xCB17B4 |
| TFNAttributedTextModel | contentTopPadding | 0xCB191C |
| TFNAttributedTextModel | fitToWidth: | 0xCB1A68 |
| TFNAttributedTextModel | fitToSize: | 0xCB1A88 |
| TFNAttributedTextModel | _tfn_sizeRequiresRelayout: | 0xCB1B14 |
| TFNAttributedTextModel | _tfn_buildTextProperties | 0xCB1D98 |
| TFNAttributedTextModel | _tfn_buildTextPropertiesWithTrailingString | 0xCB1E28 |
| TFNAttributedTextModel | _tfn_buildTextPropertiesInMultiLinesWithoutTrailingString | 0xCB2288 |
| TFNAttributedTextModel | _tfn_buildTextPropertiesInSingleLineWithoutTrailingString | 0xCB2300 |
| TFNAttributedTextModel | _tfn_updateTextPropertiesWithRenderedAttributedString: | 0xCB2498 |
| TFNSizeThatFitsHelper | sizeThatFits:forView:withBottomContentPadding:layout: | 0xDD3524 |
| TFNSizeThatFitsHelper | layoutSubviewsForView: | 0xDD374C |
| TFNSizeThatFitsHelper | invalidateLayoutForView: | 0xDD3798 |
| TFNSizeThatFitsHelper | _layoutSubviewsForView:atWidth: | 0xDD37E8 |

**Observed disassembly corroboration**: around `0xCB1A00` inside the text-model implementation vicinity, branch-linked `_CTFrameGetLineOrigins` and `_CGRectGetMaxY` are present. **Not yet established**: exact function-level control flow connecting those calls to a particular selector (avoid misattributing instructions merely by proximity), final layout formula, callsite in timeline body. 

**Next**: record full class-owned selectors automatically; inspect exact bounds and branches of `fitToSize:`, `_tfn_buildTextProperties` and helper `sizeThatFits:` with function starts/call graph; find timeline status view call sites; compare identical rendered text before production changes.

## 2026-10-19 execution verification and correction
The GitHub extractor was executed on the supplied original IPA. Its previous direct-string-first fallback could incorrectly accept selector-reference pointer bytes as empty/control strings. The observed 0x8000000C header is now decoded only as indirect selector references. Re-extraction yields 37 model + 7 helper methods; all IMPs are aligned and in executable sections, with the notable selector/IMP pairs above confirmed. Full method lists are in [raw evidence](OfficialXTextSizingEvidence.txt). [Function-level disassembly](OfficialXTextSizingDisassembly.md) supersedes the earlier proximity-only observation for the newly inspected functions; timeline-body relevance remains unproved.
