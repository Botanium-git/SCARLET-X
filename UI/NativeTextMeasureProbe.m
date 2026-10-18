#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "../Diagnostics/DiagnosticsStore.h"
#include <math.h>

// Privacy: only system font identifiers and aggregated Unicode category flags are logged.
static NSUInteger SXProbeCharacterFlags(NSString *text, NSRange range) {
    NSUInteger flags=0;
    NSUInteger end=MIN(text.length,NSMaxRange(range));
    for(NSUInteger i=range.location;i<end;i++) {
        unichar ch=[text characterAtIndex:i];
        if(ch>=0xD800 && ch<=0xDBFF){ flags|=1; if(i+1<end)i++; }
        else if((ch>=0x3400 && ch<=0x9FFF)||(ch>=0xF900 && ch<=0xFAFF))flags|=2;
        else if(ch==0xFE0F || ch==0xFE0E || ch==0x200D)flags|=4;
        else if(ch<0x80)flags|=8;
        else flags|=16;
    }
    return flags;
}
static NSString *SXProbeSafeFontName(NSString *value) {
    if(!value.length || value.length>96)return @"unknown";
    static NSCharacterSet *invalid=nil;
    static dispatch_once_t once;
    dispatch_once(&once,^{invalid=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."] invertedSet];});
    return [value rangeOfCharacterFromSet:invalid].location==NSNotFound?value:@"unknown";
}


// Diagnostic-only: never changes the height or rendering used by the existing table.
void SXTextProbeCompare(NSString *text, CGFloat width, UIFont *font, CGFloat legacyHeight) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SXCoreTextCompareEnabled"]) return;
    if (![text isKindOfClass:NSString.class] || text.length == 0 || !font || width <= 0.0) return;
    static NSUInteger sampleCount = 0;
    if (sampleCount >= 100) return;
    sampleCount++;

    CGFloat lineHeight = font.lineHeight;
    CGFloat spacing = 0.0;
    CGFloat zero = 0.0;
    CGFloat paragraphSpacing = 0.0;
    CTTextAlignment alignment = kCTTextAlignmentNatural;
    CTLineBreakMode lineBreak = kCTLineBreakByWordWrapping;
    CTWritingDirection direction = kCTWritingDirectionNatural;
    CTParagraphStyleSetting settings[] = {
        { kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment },
        { kCTParagraphStyleSpecifierLineBreakMode, sizeof(lineBreak), &lineBreak },
        { kCTParagraphStyleSpecifierMinimumLineHeight, sizeof(lineHeight), &lineHeight },
        { kCTParagraphStyleSpecifierMaximumLineSpacing, sizeof(spacing), &spacing },
        { kCTParagraphStyleSpecifierMinimumLineSpacing, sizeof(spacing), &spacing },
        { kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof(zero), &zero },
        { kCTParagraphStyleSpecifierParagraphSpacing, sizeof(paragraphSpacing), &paragraphSpacing },
        { kCTParagraphStyleSpecifierBaseWritingDirection, sizeof(direction), &direction }
    };
    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));
    if (!style) return;
    CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
    if (!ctFont) { CFRelease(style); return; }
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:@{
        (__bridge NSString *)kCTFontAttributeName: (__bridge id)ctFont,
        (__bridge NSString *)kCTParagraphStyleAttributeName: (__bridge id)style
    }];
    CFRelease(style);
    CFRelease(ctFont);

    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    if (!setter) return;
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0.0, 0.0, width, 100000.0), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    if (frame) {
        CFArrayRef lines = CTFrameGetLines(frame);
        CFIndex count = lines ? CFArrayGetCount(lines) : 0;
        CGFloat resultHeight = 0.0;
        if (count > 0) {
            CGPoint *origins = calloc((size_t)count, sizeof(CGPoint));
            if (origins) {
                CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
                CGFloat firstTop = -CGFLOAT_MAX;
                CGFloat lastBottom = CGFLOAT_MAX;
                NSMutableArray<NSString *> *lineMetrics = [NSMutableArray array];
                NSMutableArray<NSString *> *lineFonts = [NSMutableArray array];
                NSMutableArray<NSString *> *lineFlags = [NSMutableArray array];
                for (CFIndex i = 0; i < count; i++) {
                    CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
                    CGFloat ascent = 0.0, descent = 0.0, leading = 0.0;
                    CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
                    firstTop = MAX(firstTop, origins[i].y + ascent);
                    lastBottom = MIN(lastBottom, origins[i].y - descent);
                    CFRange range = CTLineGetStringRange(line);
                    CFArrayRef runs = CTLineGetGlyphRuns(line);
                    CFIndex runCount = runs ? CFArrayGetCount(runs) : 0;
                    NSUInteger fallbackRuns = 0;
                    uint32_t fontSignature = 2166136261u;
                    NSMutableOrderedSet<NSString *> *fontNames=[NSMutableOrderedSet orderedSet];
                    for (CFIndex j = 0; j < runCount; j++) {
                        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, j);
                        NSDictionary *attrs = (__bridge NSDictionary *)CTRunGetAttributes(run);
                        CTFontRef runFont = (__bridge CTFontRef)attrs[(__bridge NSString *)kCTFontAttributeName];
                        if (!runFont) continue;
                        CFStringRef ps = CTFontCopyPostScriptName(runFont);
                        NSString *fontName = CFBridgingRelease(ps);
                        if (![fontName isEqualToString:font.fontName]) fallbackRuns++;
                        [fontNames addObject:SXProbeSafeFontName(fontName)];
                        for (NSUInteger k = 0; k < fontName.length; k++) {
                            fontSignature = (fontSignature ^ [fontName characterAtIndex:k]) * 16777619u;
                        }
                    }
                    CGFloat baselineGap = i > 0 ? origins[i-1].y - origins[i].y : 0.0;
                    [lineFonts addObject:fontNames.count?[[fontNames array] componentsJoinedByString:@","]:@"unknown"];
                    [lineFlags addObject:[NSString stringWithFormat:@"%lu",(unsigned long)SXProbeCharacterFlags(text,NSMakeRange((NSUInteger)range.location,(NSUInteger)range.length))]];
                    [lineMetrics addObject:[NSString stringWithFormat:@"%ld,%ld,%.2f,%.2f,%.2f,%.2f,%ld,%lu,%u",
                        (long)range.location, (long)range.length, (double)ascent, (double)descent,
                        (double)leading, (double)baselineGap, (long)runCount,
                        (unsigned long)fallbackRuns, (unsigned int)fontSignature]];
                }
                resultHeight = ceil(MAX(0.0, firstTop - lastBottom));
                NSString *metrics = [lineMetrics componentsJoinedByString:@"|"];
                NSString *summary = [NSString stringWithFormat:@"sample=%lu chars=%lu width=%.2f font=%.2f lines=%ld legacy=%.2f coreText=%.2f delta=%.2f metrics=%@ fontNames=%@ types=%@",
                    (unsigned long)sampleCount, (unsigned long)text.length, (double)width,
                    (double)font.pointSize, (long)count, (double)legacyHeight,
                    (double)resultHeight, (double)(resultHeight - legacyHeight), metrics,
                    [lineFonts componentsJoinedByString:@"|"],[lineFlags componentsJoinedByString:@"|"]];
                [[DiagnosticsStore shared] addEvent:@"Core Text本文高さ比較" detail:summary url:nil];
                free(origins);
            }
        }
        CFRelease(frame);
    }
    CGPathRelease(path);
    CFRelease(setter);
}
