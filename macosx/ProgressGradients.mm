// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "ProgressGradients.h"
#import "NSApplicationAdditions.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5

static void TRProgressGradientEvaluate(void* info, CGFloat const* input, CGFloat* output)
{
    CGFloat const* components = static_cast<CGFloat const*>(info);
    CGFloat const position = input[0];
    CGFloat const fraction = position <= 0.5 ? position * 2.0 : (position - 0.5) * 2.0;
    NSUInteger const start = position <= 0.5 ? 0 : 8;
    NSUInteger const end = position <= 0.5 ? 4 : 0;
    for (NSUInteger component = 0; component < 4; ++component)
    {
        output[component] = components[start + component] + (components[end + component] - components[start + component]) * fraction;
    }
}

@implementation TRProgressGradient

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    if ((self = [super init]))
    {
        CGFloat const baseComponents[] = { red, green, blue, alpha };
        for (NSUInteger component = 0; component < 4; ++component)
        {
            fComponents[component] = baseComponents[component];
            fComponents[4 + component] = component == 3 ? alpha : baseComponents[component] * 0.95;
            fComponents[8 + component] = component == 3 ? alpha : baseComponents[component] * 0.85;
        }
    }
    return self;
}

- (void)drawInRect:(NSRect)rect angle:(CGFloat)angle
{
    NSAssert(angle == 90.0, @"TRProgressGradient implements only Transmission's 90-degree gradient path");

    static CGFloat const domain[] = { 0.0, 1.0 };
    static CGFloat const range[] = { 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0 };
    CGFunctionCallbacks callbacks = { 0, TRProgressGradientEvaluate, NULL };
    CGFunctionRef function = CGFunctionCreate(fComponents, 1, domain, 4, range, &callbacks);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGPoint const start = CGPointMake(NSMinX(rect), NSMinY(rect));
    CGPoint const end = CGPointMake(NSMinX(rect), NSMaxY(rect));
    CGShadingRef shading = CGShadingCreateAxial(colorSpace, start, end, function, false, false);

    NSGraphicsContext* graphicsContext = [NSGraphicsContext currentContext];
    [graphicsContext saveGraphicsState];
    [NSBezierPath clipRect:rect];
    CGContextDrawShading((CGContextRef)[graphicsContext graphicsPort], shading);
    [graphicsContext restoreGraphicsState];

    CGShadingRelease(shading);
    CGColorSpaceRelease(colorSpace);
    CGFunctionRelease(function);
}

@end

#endif

@implementation ProgressGradients

+ (TRProgressGradient*)progressWhiteGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.1 green:0.1 blue:0.1];
    }
    else
    {
        return [[self class] progressGradientForRed:0.95 green:0.95 blue:0.95];
    }
}

+ (TRProgressGradient*)progressGrayGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.35 green:0.35 blue:0.35];
    }
    else
    {
        return [[self class] progressGradientForRed:0.7 green:0.7 blue:0.7];
    }
}

+ (TRProgressGradient*)progressLightGrayGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.2 green:0.2 blue:0.2];
    }
    else
    {
        return [[self class] progressGradientForRed:0.87 green:0.87 blue:0.87];
    }
}

+ (TRProgressGradient*)progressBlueGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.35 * 2.0 / 3.0 green:0.67 * 2.0 / 3.0 blue:0.98 * 2.0 / 3.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.35 green:0.67 blue:0.98];
    }
}

+ (TRProgressGradient*)progressDarkBlueGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.616 * 2.0 / 3.0 green:0.722 * 2.0 / 3.0 blue:0.776 * 2.0 / 3.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.616 green:0.722 blue:0.776];
    }
}

+ (TRProgressGradient*)progressGreenGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.44 * 2.0 / 3.0 green:0.89 * 2.0 / 3.0 blue:0.40 * 2.0 / 3.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.44 green:0.89 blue:0.40];
    }
}

+ (TRProgressGradient*)progressLightGreenGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.62 * 3.0 / 4.0 green:0.99 * 3.0 / 4.0 blue:0.58 * 3.0 / 4.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.62 green:0.99 blue:0.58];
    }
}

+ (TRProgressGradient*)progressDarkGreenGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.627 * 2.0 / 3.0 green:0.714 * 2.0 / 3.0 blue:0.639 * 2.0 / 3.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.627 green:0.714 blue:0.639];
    }
}

+ (TRProgressGradient*)progressRedGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.902 * 2.0 / 3.0 green:0.439 * 2.0 / 3.0 blue:0.451 * 2.0 / 3.0];
    }
    else
    {
        return [[self class] progressGradientForRed:0.902 green:0.439 blue:0.451];
    }
}

+ (TRProgressGradient*)progressYellowGradient
{
    if ([NSApp isDarkMode])
    {
        return [[self class] progressGradientForRed:0.933 * 0.8 green:0.890 * 0.8 blue:0.243 * 0.8];
    }
    else
    {
        return [[self class] progressGradientForRed:0.933 green:0.890 blue:0.243];
    }
}

#pragma mark - Private

+ (TRProgressGradient*)progressGradientForRed:(CGFloat)redComponent green:(CGFloat)greenComponent blue:(CGFloat)blueComponent
{
    CGFloat const alpha = [NSUserDefaults.standardUserDefaults boolForKey:@"SmallView"] ? 0.27 : 1.0;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_5
    return [[TRProgressGradient alloc] initWithRed:redComponent green:greenComponent blue:blueComponent alpha:alpha];
#else
    NSColor* baseColor = [NSColor colorWithCalibratedRed:redComponent green:greenComponent blue:blueComponent alpha:alpha];
    NSColor* color2 = [NSColor colorWithCalibratedRed:redComponent * 0.95 green:greenComponent * 0.95 blue:blueComponent * 0.95
                                                alpha:alpha];
    NSColor* color3 = [NSColor colorWithCalibratedRed:redComponent * 0.85 green:greenComponent * 0.85 blue:blueComponent * 0.85
                                                alpha:alpha];
    return [[NSGradient alloc] initWithColorsAndLocations:baseColor, 0.0, color2, 0.5, color3, 0.5, baseColor, 1.0, nil];
#endif
}

@end
