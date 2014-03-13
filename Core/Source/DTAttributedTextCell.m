//
//  DTAttributedTextCell.m
//  DTCoreText
//
//  Created by Oliver Drobnik on 8/4/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTCoreText.h"
#import "DTAttributedTextCell.h"
#import "DTCSSStylesheet.h"
#import "DTLog.h"

@implementation DTAttributedTextCell
{
	DTAttributedTextContentView *_attributedTextContextView;
	
	DT_WEAK_VARIABLE id <DTAttributedTextContentViewDelegate> _textDelegate;
	
	NSUInteger _htmlHash; // preserved hash to avoid relayouting for same HTML
	
	BOOL _hasFixedRowHeight;
	DT_WEAK_VARIABLE UITableView *_containingTableView;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	
    if (self)
	{
		// content view created lazily
    }
	
    return self;
}

- (void)dealloc
{
	_textDelegate = nil;
	_containingTableView = nil;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (!self.superview)
	{
		return;
	}
	
	if (_hasFixedRowHeight)
	{
		self.attributedTextContextView.frame = self.contentView.bounds;
	}
	else
	{
		CGFloat neededContentHeight = [self requiredRowHeightInTableView:_containingTableView];
		
		// after the first call here the content view size is correct
		CGRect frame = CGRectMake(0, 0, self.contentView.bounds.size.width, neededContentHeight);
		// only change frame if width has changed to avoid extra layouting
		// Hsoi 2013-05-30 - or if the current height is less than what we need
		if (_attributedTextContextView.frame.size.width != frame.size.width || _attributedTextContextView.frame.size.height < neededContentHeight)
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
			//
			// Hsoi 2013-08-19 - iOS 7 seems to change the hierarchy a bit, so we'll have to walk up the superviews.
			
			UITableView*		parentTable = nil;
			UIView*			theSuperview = self;
			while ((theSuperview = [theSuperview superview])) {
				if ([theSuperview isKindOfClass:[UITableView class]]) {
					parentTable = (UITableView*)theSuperview;
					break;
				}
			}
			
			[parentTable beginUpdates];
			[parentTable endUpdates];
		}
	}
}

- (UITableView *)_findContainingTableView
{
	UIView *tableView = self.superview;
	
	while (tableView)
	{
		if ([tableView isKindOfClass:[UITableView class]])
		{
			return (UITableView *)tableView;
		}
		
		tableView = tableView.superview;
	}
	
	return nil;
}

- (void)didMoveToSuperview
{
	[super didMoveToSuperview];
	
	_containingTableView = [self _findContainingTableView];
	
	// on < iOS 7 we need to make the background translucent to avoid artefacts at rounded edges
	if (_containingTableView.style == UITableViewStyleGrouped)
	{
		if (NSFoundationVersionNumber < DTNSFoundationVersionNumber_iOS_7_0)
		{
			_attributedTextContextView.backgroundColor = [UIColor clearColor];
		}
	}
}

// http://stackoverflow.com/questions/4708085/how-to-determine-margin-of-a-grouped-uitableview-or-better-how-to-set-it/4872199#4872199
- (CGFloat)_groupedCellMarginWithTableWidth:(CGFloat)tableViewWidth
{
    CGFloat marginWidth;
    if(tableViewWidth > 20)
    {
        if(tableViewWidth < 400 || [UIDevice currentDevice].userInterfaceIdiom==UIUserInterfaceIdiomPhone)
        {
            marginWidth = 10;
        }
        else
        {
            marginWidth = MAX(31.f, MIN(45.f, tableViewWidth*0.06f));
        }
    }
    else
    {
        marginWidth = tableViewWidth - 10;
    }
    return marginWidth;
}

- (CGFloat)requiredRowHeightInTableView:(UITableView *)tableView
{
	if (_hasFixedRowHeight)
	{
		DTLogWarning(@"You are calling %s even though the cell is configured with fixed row height", (const char *)__PRETTY_FUNCTION__);
	}
	
	BOOL ios6Style = (NSFoundationVersionNumber < DTNSFoundationVersionNumber_iOS_7_0);
	CGFloat contentWidth = tableView.frame.size.width;
	
	// reduce width for grouped table views
	if (ios6Style && tableView.style == UITableViewStyleGrouped)
	{
		contentWidth -= [self _groupedCellMarginWithTableWidth:contentWidth] * 2;
	}
	
	// reduce width for accessories
	
	switch (self.accessoryType)
	{
		case UITableViewCellAccessoryDisclosureIndicator:
		{
			contentWidth -= ios6Style ? 20.0f : 10.0f + 8.0f + 15.0f;
			break;
		}
			
		case UITableViewCellAccessoryCheckmark:
		{
			contentWidth -= ios6Style ? 20.0f : 10.0f + 14.0f + 15.0f;
			break;
		}
			
		case UITableViewCellAccessoryDetailDisclosureButton:
		{
			contentWidth -= ios6Style ? 33.0f : 10.0f + 42.0f + 15.0f;
			break;
		}
			
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
		case UITableViewCellAccessoryDetailButton:
		{
			contentWidth -= 10.0f + 22.0f + 15.0f;
			break;
		}
#endif
			
		case UITableViewCellAccessoryNone:
		{
			break;
		}
			
		default:
		{
			DTLogWarning(@"AccessoryType %d not implemented on %@", self.accessoryType, NSStringFromClass([self class]));
			break;
		}
	}
	
	CGSize neededSize = [self.attributedTextContextView suggestedFrameSizeToFitEntireStringConstraintedToWidth:contentWidth];
	
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
	[self setHTMLString:html options:nil];
}

- (void) setHTMLString:(NSString *)html options:(NSDictionary*) options {
	
	NSUInteger newHash = [html hash];
	
	if (newHash == _htmlHash)
	{
		return;
	}
	
	_htmlHash = newHash;
	
	NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
	NSAttributedString *string = [[NSAttributedString alloc] initWithHTMLData:data options:options documentAttributes:NULL];
	self.attributedString = string;
	
	[self setNeedsLayout];
	
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
	// passthrough
	self.attributedTextContextView.attributedString = attributedString;
}

- (NSAttributedString *)attributedString
{
	// passthrough
	return _attributedTextContextView.attributedString;
}

- (DTAttributedTextContentView *)attributedTextContextView
{
	if (!_attributedTextContextView)
	{
		// don't know size jetzt because there's no string in it
		_attributedTextContextView = [[DTAttributedTextContentView alloc] initWithFrame:self.contentView.bounds];
		
		_attributedTextContextView.edgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
		_attributedTextContextView.layoutFrameHeightIsConstrainedByBounds = _hasFixedRowHeight;
		_attributedTextContextView.delegate = _textDelegate;
		
		[self.contentView addSubview:_attributedTextContextView];
	}
	
	return _attributedTextContextView;
}

- (void)setHasFixedRowHeight:(BOOL)hasFixedRowHeight
{
	if (_hasFixedRowHeight != hasFixedRowHeight)
	{
		_hasFixedRowHeight = hasFixedRowHeight;
		
		[self setNeedsLayout];
	}
}

- (void)setTextDelegate:(id)textDelegate
{
	_textDelegate = textDelegate;
	_attributedTextContextView.delegate = _textDelegate;
}

@synthesize attributedTextContextView = _attributedTextContextView;
@synthesize hasFixedRowHeight = _hasFixedRowHeight;
@synthesize textDelegate = _textDelegate;

@end
