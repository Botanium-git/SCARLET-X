# Official X v12.25 text rendering analysis: evidence status

This is a *findings register*, not a substitute for raw binary data or the full history of prior investigations.

## Primary artifacts (external to repository unless separately uploaded)
- Original IPA: com.atebits.Tweetie2_12.25_und3fined(1).ipa (local analyst input).
- Mach-O SQLite: scarlet_macho(1).sqlite (local analyst input); inspect version/hash before relying on long-term provenance.
- Indexed binaries: T1Twitter (33,287,408 bytes); XAppLibraries (124,141,728 bytes).
- SQLite tables: binaries, strings, symbols, functions, imports, objc_methods. As checked 2026-10-19, counts: binaries 2; strings 791720; symbols 50497; functions 501544; imports 0; objc_methods 57951.
- The SQLite is a raw search INDEX, **not** an authoritative notebook of reverse-engineering conclusions. Findings from prior chats may not be represented here.

## Confirmed by inspected SQLite symbol records
- `_OBJC_CLASS_$_TFNAttributedTextModel` occurs as kind `*UND*` in both binaries: external reference; class implementation NOT established from this finding.
- `_OBJC_CLASS_$_TFNSizeThatFitsHelper` occurs as kind `*UND*` in both binaries: external reference.
- `_CTLineGetTypographicBounds` occurs as kind `*UND*`: external function reference. This alone does NOT identify its use for timeline text.
- The imports table has 0 rows in this particular DB; do not confuse lack of import records with proof of no dependency.

## Confirmed in Scarlet X v1.4.166 instrumentation
- NSString boundingRectWithSize (legacy) vs a Core Text typographic-span experiment (first ascent, baseline origin differences, last descent) yielded differences of 0, +5, +6, +11, +18pt for sampled 13pt text at 328pt width.
- AppleColorEmoji was present in all recorded disagreement samples, but some lines also contained other fallback fonts.
- These are **Scarlet X internal method differences**, not official X measurements.

## Newly confirmed definition location (2026-10-19)
- Full IPA inspected: XServiceLibraries.framework/XServiceLibraries defines ObjC class symbols TFNAttributedTextModel (0x04422590) and TFNSizeThatFitsHelper (0x0442A3A8). See OX-005 in OfficialXFindingsLedger.md. This does not establish timeline-body sizing behavior.

## Not yet confirmed
- Which official X component actually measures a timeline post's body.
- Which text attributes, font selection, line-break policies, baseline/leading/rounding rules official X uses.
- Whether TFNAttributedTextModel / TFNSizeThatFitsHelper implement the observed timeline-body height calculation.
- Official X rendered heights for the exact same controlled strings and environment used in Scarlet X.
- Proof that the current Core Text experiment matches official X.

## Next research / validation
1. Inspect the XServiceLibraries class implementations and identify an *actual call chain* for timeline-body text measurement.
2. Correlate code paths to timeline post body UI before claiming relevance.
3. Compare identical text on the same device, same effective font size and width in official X and Scarlet X.
4. Document each confirmed conclusion with source binary, function address, disassembly/call graph, or actual experiment data.
5. Do not alter production typography or row calculation until an official-X comparison supports it.

## 2026-10-19 static disassembly update (OX-011–014)
- See [full reconstruction](OfficialXTextSizingDisassembly.md) and [raw evidence](OfficialXTextSizingEvidence.txt).
- Class-owned fitToSize: directly calls _TFN_CTFrameGetSizeWithMaxLines. Its width scan, selected-line height formula, +3.0 constant, float32 conversions and upward rounding are now statically resolved. All six previously unresolved call targets are identified.
- Text-property branch selectors and Single/Multi → CTFrame construction are resolved. Full frame creation and attribute transformation remain pending.
- The original class extractor had an indirect-selector decoding bug; fixed and executed for all 44 methods, including executable/aligned IMP validation.
- Earlier statements about unknown implementation methods are superseded for these specific paths, while timeline-body use, caller ownership, runtime typography and official-device parity remain unconfirmed.

## 2026-10-19 continuation (OX-015–018)
- Frame construction/maxLines clipping path is now statically reconstructed at 0xC9FE48 (see existing disassembly report).
- Correction to OX-001: T1Twitter 0x408300 belongs to the metaclass T1StatusWithheldInCountryView; it is not established as the ordinary timeline-body builder.
- XAppLibraries now supplies a concrete status/display-text-model path: TFNTwitterStatus → new TFNTwitterDisplayTextModel allocation → bound TFNAttributedTextModel allocation/initializer. Cache paths also exist.
- Display-model height API uses fitToWidth: / actualSize, float32 upward rounding and a signed 64-bit integer return; frame-generation, caller and cache conditions are documented separately.
- Ordinary timeline UI options, font/attribute generation and final table-row composition remain pending. No production typography changes or official-device parity claims.
