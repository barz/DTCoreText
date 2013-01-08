//
//  DTAttributedTextCell.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 8/4/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTCoreText.h"
#import "DTAttributedTextCell.h"
#import "DTCSSStylesheet.h"

@implementation DTAttributedTextCell
{
	NSAttributedString *_attributedString;
	DTAttributedTextContentView *_attributedTextContextView;
	
	NSUInteger _htmlHash; // preserved hash to avoid relayouting for same HTML
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier accessoryType:(UITableViewCellAccessoryType)accessoryType
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) 
	{
		// don't know size jetzt because there's no string in it
		_attributedTextContextView = [[DTAttributedTextContentView alloc] initWithFrame:CGRectZero];
		_attributedTextContextView.edgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
		[self.contentView addSubview:_attributedTextContextView];
    }
    return self;
}


- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGFloat neededContentHeight = [self requiredRowHeightInTableView:(UITableView *)self.superview];
	
	// after the first call here the content view size is correct
	CGRect frame = CGRectMake(0, 0, self.contentView.bounds.size.width, neededContentHeight);
	
	// only change frame if width has changed to avoid extra layouting
	if (_attributedTextContextView.frame.size.width != frame.size.width)
	{
		_attributedTextContextView.frame = frame;

		// Hsoi 08-Jan-2013 - To deal with a dynamic size flow issue: https://github.com/Cocoanetics/DTCoreText/issues/102
		//
		// The DTCoreText demo has it such that the -[UITableViewController tableView:heightForRowAtIndexPath:] implementation
		// calls -[DTAttributedTextCell requiredRowHeightInTableView:] to get the height. Unfortunately, that number often
		// winds up being different than the _attributedTextContextView.frame that gets set above! That's not good.
		// After some looking at the #102 and then also https://github.com/Cocoanetics/DTCoreText/issues/114 it seems that
		// there's just issues with the OS and how things cooperate and work. *sigh*
		//
		// So after thinking about it and trying some other approaches towards solving this, I have what appears
		// to be a workaround.
		//
		// The key is that the cell's height needs to be the same as the HTML we're actually rendering, thus the
		// _attributedTextContextView. Thus, -[UITableViewController tableView:heightForRowAtIndexPath:] should
		// return the value of cell.attributedTextContextView.frame.size.height; Simple and proper, right?
		//
		// The trick tho is getting the proper height. Well, it's HERE that this happens, but we need some way
		// to kick the UITableView to then not just draw, but to know to refetch the cell heights. So while
		// this isn't 100% non-dirty, it works to kick it by getting the parent view, which happens to
		// be a UITableView, and then doing the -beginUpdates/-endUpdates bracket. And yes, it will reflow
		// things to work. Huzzah!
		//
		//
		// So note, to make this work, the -[UITableViewController tableView:heightForRowAtIndexPath:] needs to
		// return cell.attributedTextContextView.frame.size.height.
	
#if DEBUG
		if ([self superview] != nil) {
			NSParameterAssert([[self superview] isKindOfClass:[UITableView class]]);
		}
#endif
		UITableView*	parentTable = (UITableView*)[self superview];
		[parentTable beginUpdates];
		[parentTable endUpdates];
	}
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
	UITableView *tableView = (UITableView *)newSuperview;
	
	if (tableView.style == UITableViewStyleGrouped)
	{
		// need no background because otherwise this would overlap the rounded corners
		_attributedTextContextView.backgroundColor = [DTColor clearColor];
	}
	
	[super willMoveToSuperview:newSuperview];
}

- (CGFloat)requiredRowHeightInTableView:(UITableView *)tableView
{
	
	CGFloat contentWidth = tableView.frame.size.width;

	// reduce width for accessories
	switch (self.accessoryType) 
	{
		case UITableViewCellAccessoryDisclosureIndicator:
		case UITableViewCellAccessoryCheckmark:
			contentWidth -= 20.0f;
			break;
		case UITableViewCellAccessoryDetailDisclosureButton:
			contentWidth -= 33.0f;
			break;
		case UITableViewCellAccessoryNone:
			break;
	}
	
	// reduce width for grouped table views
	if (tableView.style == UITableViewStyleGrouped)
	{
		contentWidth -= 19;
	}
	
	CGSize neededSize = [_attributedTextContextView suggestedFrameSizeToFitEntireStringConstraintedToWidth:contentWidth];
	
	// note: non-integer row heights caused trouble < iOS 5.0
	return neededSize.height;
}

#pragma mark Properties


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setHTMLString:(NSString *)html
{
	// we don't preserve the html but compare it's hash
	NSUInteger newHash = [html hash];
	
	if (newHash == _htmlHash)
	{
		return;
	}
	
	_htmlHash = newHash;
	
	NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
	NSAttributedString *string = [[NSAttributedString alloc] initWithHTMLData:data documentAttributes:NULL];
	self.attributedString = string;
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
	if (_attributedString != attributedString)
	{
		_attributedString = attributedString;
		
		// passthrough
		_attributedTextContextView.attributedString = _attributedString;
	}
}

@synthesize attributedString = _attributedString;
@synthesize attributedTextContextView = _attributedTextContextView;

@end
