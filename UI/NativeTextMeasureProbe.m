#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#include <math.h>

// Diagnostic-only: never changes the height or rendering used by the existing table.
void SXTextProbeCompare(NSString *text, CGFloat width, UIFont *font, CGFloat legacyHeight) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SXCoreTextCompareEnabled"]) return;
    if (![text isKindOfClass:NSString.class] || text.length == 0 || !font || width <= 0.0) return;
    static NSUInteger sampleCount = 0;
    if (sampleCount >= 200) return;
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
                for (CFIndex i = 0; i < count; i++) {
                    CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, i);
                    CGFloat ascent = 0.0, descent = 0.0, leading = 0.0;
                    CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
                    firstTop = MAX(firstTop, origins[i].y + ascent);
                    lastBottom = MIN(lastBottom, origins[i].y - descent);
                }
                resultHeight = ceil(MAX(0.0, firstTop - lastBottom));
                free(origins);
            }
        }
        NSLog(@"[SXCoreTextCompare] sample=%lu chars=%lu width=%.2f font=%.2f lines=%ld legacy=%.2f coreText=%.2f delta=%.2f",
              (unsigned long)sampleCount, (unsigned long)text.length, (double)width,
              (double)font.pointSize, (long)count, (double)legacyHeight,
              (double)resultHeight, (double)(resultHeight - legacyHeight));
        CFRelease(frame);
    }
    CGPathRelease(path);
    CFRelease(setter);
}
