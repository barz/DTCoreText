//
//  NSScanner+HTML.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/12/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "NSScanner+HTML.h"
#import "NSCharacterSet+HTML.h"

@implementation NSScanner (HTML)

- (NSString *)peekNextTagSkippingClosingTags:(BOOL)skipClosingTags
{
	NSScanner *scanner = [[self copy] autorelease];
	
	do
	{
		NSString *textUpToNextTag = nil;
		
		if ([scanner scanUpToString:@"<" intoString:&textUpToNextTag])
		{
			// Check if there are alpha chars after the end tag
			NSScanner *subScanner = [NSScanner scannerWithString:textUpToNextTag];
			[subScanner scanUpToString:@">" intoString:NULL];
			[subScanner scanString:@">" intoString:NULL];
			
			// Rest might be alpha
			NSString *rest = [[textUpToNextTag substringFromIndex:subScanner.scanLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			// We don't want a newline in this case so we send back any inline character
			if ([rest length])
			{
				return @"b";
			}
		}
		
		[scanner scanString:@"<" intoString:NULL];
	} while (skipClosingTags&&[scanner scanString:@"/" intoString:NULL]);
	
	NSString *nextTag = nil;
	
	[scanner scanCharactersFromSet:[NSCharacterSet tagNameCharacterSet] intoString:&nextTag];
	
	return [nextTag lowercaseString];
}

- (BOOL)scanHTMLTag:(NSString **)tagName attributes:(NSDictionary **)attributes isOpen:(BOOL *)isOpen isClosed:(BOOL *)isClosed
{
	
	NSInteger initialScanLocation = [self scanLocation];
	
	if (![self scanString:@"<" intoString:NULL])
	{
		[self setScanLocation:initialScanLocation];
		return NO;
	}
	
	BOOL tagOpen = YES;
	BOOL immediatelyClosed = NO;
	
	NSCharacterSet *tagCharacterSet = [NSCharacterSet tagNameCharacterSet];
	NSCharacterSet *quoteCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
	NSCharacterSet *whiteCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	NSString *scannedTagName = nil;
	NSMutableDictionary *tmpAttributes = [NSMutableDictionary dictionary];
	
	if ([self scanString:@"/" intoString:NULL])
	{
		// Close of tag
		tagOpen = NO;
	}
	
	[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];

	// Read the tag name
	if (![self scanCharactersFromSet:tagCharacterSet intoString:&scannedTagName])
	{
		[self setScanLocation:initialScanLocation];
		return NO;
	}

	// make tags lowercase
	scannedTagName = [scannedTagName lowercaseString];
	
	//[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
	
	// Read attributes of tag
	while (![self isAtEnd])
	{
		if ([self scanString:@"/" intoString:NULL])
		{
			
			immediatelyClosed = YES;
			break;
		}
		
		if ([self scanString:@">" intoString:NULL])
		{
			break;
		}
		
		[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
		
		NSString *attrName = nil;
		NSString *attrValue = nil;
		
		if (![self scanCharactersFromSet:tagCharacterSet intoString:&attrName])
		{
			[self setScanLocation:initialScanLocation];
			return NO;
		}
		
		attrName = [attrName lowercaseString];
		
		[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
		
		if (![self scanString:@"=" intoString:nil])
		{
			// solo attribute
			[tmpAttributes setObject:attrName forKey:attrName];
		}
		else 
		{
			// attribute = value
			NSString *quote = nil;
			
			[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
			
			if ([self scanCharactersFromSet:quoteCharacterSet intoString:&quote])
			{
				[self scanUpToString:quote intoString:&attrValue];	
				[self scanString:quote intoString:NULL];
				
				[tmpAttributes setObject:attrValue forKey:attrName];
			}
		}
		
		[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
	}

	// skip ending bracket
	//[self scanCharactersFromSet:whiteCharacterSet intoString:NULL];
	//[self scanString:@">" intoString:NULL];
	
	
	// Success 
	if (isClosed)
	{
		*isClosed = immediatelyClosed;
	}
	
	if (isOpen)
	{
		*isOpen = tagOpen;
	}
	
	if (attributes)
	{
		*attributes = [NSDictionary dictionaryWithDictionary:tmpAttributes];
	}
	
	if (tagName)
	{
		*tagName = scannedTagName;
	}
	
	return YES;
}


@end