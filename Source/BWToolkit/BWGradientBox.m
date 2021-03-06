//
//  BWGradientBox.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWGradientBox.h"
#import "NSColor+BWAdditions.h"

@implementation BWGradientBox

@synthesize fillStartingColor, fillEndingColor, fillColor, topBorderColor, bottomBorderColor;
@synthesize topInsetAlpha, bottomInsetAlpha;
@synthesize hasTopBorder, hasBottomBorder, hasGradient, hasFillColor;

@synthesize cornerRadius;
@synthesize shadow;

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setFillStartingColor:[decoder decodeObjectForKey:@"BWGBFillStartingColor"]];
		[self setFillEndingColor:[decoder decodeObjectForKey:@"BWGBFillEndingColor"]];
		[self setFillColor:[decoder decodeObjectForKey:@"BWGBFillColor"]];
		[self setTopBorderColor:[decoder decodeObjectForKey:@"BWGBTopBorderColor"]];
		[self setBottomBorderColor:[decoder decodeObjectForKey:@"BWGBBottomBorderColor"]];
		
		[self setHasTopBorder:[decoder decodeBoolForKey:@"BWGBHasTopBorder"]];
		[self setHasBottomBorder:[decoder decodeBoolForKey:@"BWGBHasBottomBorder"]];
		[self setHasGradient:[decoder decodeBoolForKey:@"BWGBHasGradient"]];
		[self setHasFillColor:[decoder decodeBoolForKey:@"BWGBHasFillColor"]];

		[self setTopInsetAlpha:[decoder decodeFloatForKey:@"BWGBTopInsetAlpha"]];
		[self setBottomInsetAlpha:[decoder decodeFloatForKey:@"BWGBBottomInsetAlpha"]];
		
		if (self.fillStartingColor == nil)
			self.fillStartingColor = [NSColor whiteColor];
		
		if (self.fillEndingColor == nil)
			self.fillEndingColor = [NSColor grayColor];
		
		if (self.fillColor == nil)
			self.fillColor = [NSColor grayColor];
		
		if (self.topBorderColor == nil)
			self.topBorderColor = [NSColor blackColor];
		
		if (self.bottomBorderColor == nil)
			self.bottomBorderColor = [NSColor blackColor];
    
    self.cornerRadius = [decoder decodeFloatForKey: @"BWGBCornerRadius"];
		self.shadow = [decoder decodeObjectForKey: @"BWGBShadow"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
	
	[coder encodeObject:[self fillStartingColor] forKey:@"BWGBFillStartingColor"];
	[coder encodeObject:[self fillEndingColor] forKey:@"BWGBFillEndingColor"];
	[coder encodeObject:[self fillColor] forKey:@"BWGBFillColor"];
	[coder encodeObject:[self topBorderColor] forKey:@"BWGBTopBorderColor"];
	[coder encodeObject:[self bottomBorderColor] forKey:@"BWGBBottomBorderColor"];
	
	[coder encodeBool:[self hasTopBorder] forKey:@"BWGBHasTopBorder"];
	[coder encodeBool:[self hasBottomBorder] forKey:@"BWGBHasBottomBorder"];
	[coder encodeBool:[self hasGradient] forKey:@"BWGBHasGradient"];
	[coder encodeBool:[self hasFillColor] forKey:@"BWGBHasFillColor"];
	
	[coder encodeFloat:[self topInsetAlpha] forKey:@"BWGBTopInsetAlpha"];
	[coder encodeFloat:[self bottomInsetAlpha] forKey:@"BWGBBottomInsetAlpha"];
  
  [coder encodeFloat: cornerRadius forKey: @"BWGBCornerRadius"];
	[coder encodeObject: self.shadow forKey: @"BWGBShadow"];
} 

- (void)drawRect:(NSRect)rect 
{
  [NSGraphicsContext saveGraphicsState];

  NSBezierPath* borderPath = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect([self bounds], cornerRadius, cornerRadius) xRadius: cornerRadius yRadius: cornerRadius];
  
  if (shadow != nil) {
    [shadow set];
    [[NSColor whiteColor] set];
    [borderPath fill];
  }
  [borderPath addClip];
  
	if (hasGradient)
	{
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:fillStartingColor endingColor:fillEndingColor];
		//[gradient drawInRect:self.bounds angle:90];
    [gradient drawInBezierPath: borderPath angle: 90];
	}
	else
	{
		if (hasFillColor)
		{
			[fillColor set];
			NSRectFillUsingOperation(self.bounds, NSCompositeSourceOver);	
		}
	}
	
	if (hasTopBorder)
	{
		[topBorderColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
		[[[NSColor whiteColor] colorWithAlphaComponent:topInsetAlpha] bwDrawPixelThickLineAtPosition:1 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
	}
	else
	{
		[[[NSColor whiteColor] colorWithAlphaComponent:topInsetAlpha] bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
	}
		
	
	if (hasBottomBorder)
	{
		[bottomBorderColor bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
		[[[NSColor whiteColor] colorWithAlphaComponent:bottomInsetAlpha] bwDrawPixelThickLineAtPosition:1 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
	}
	else
	{
		[[[NSColor whiteColor] colorWithAlphaComponent:bottomInsetAlpha] bwDrawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
	}

  [NSGraphicsContext restoreGraphicsState];
}

- (BOOL)isFlipped
{
	return NO;
}

- (void)setFillColor:(NSColor *)color
{
	if (fillColor != color) 
	{
        fillColor = color;
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setFillStartingColor:(NSColor *)color
{
	if (fillStartingColor != color) 
	{
        fillStartingColor = color;
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setFillEndingColor:(NSColor *)color
{
	if (fillEndingColor != color) 
	{
        fillEndingColor = color;
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setTopBorderColor:(NSColor *)color
{
	if (topBorderColor != color) 
	{
        topBorderColor = color;
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setBottomBorderColor:(NSColor *)color
{
	if (bottomBorderColor != color) 
	{
        bottomBorderColor = color;
		
		[self setNeedsDisplay:YES];
    }
}


@end
