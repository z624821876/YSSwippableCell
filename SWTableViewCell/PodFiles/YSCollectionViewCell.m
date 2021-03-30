//
//  YSCollectionViewCell.m
//  SWTableViewCell
//
//  Created by yu on 2021/3/30.
//  Copyright © 2021 Chris Wendel. All rights reserved.
//

#import "YSCollectionViewCell.h"
#import "SWUtilityButtonView.h"

#define kSectionIndexWidth 15
#define kAccessoryTrailingSpace 15
#define kLongPressMinimumDuration 0.16f

@interface YSCollectionViewCell() <UIScrollViewDelegate,  UIGestureRecognizerDelegate>

@property (nonatomic, weak) UICollectionView *containingCollectionView;

@property (nonatomic, strong) UIPanGestureRecognizer *collectionViewPanGestureRecognizer;

@property (nonatomic, assign) SWCellState cellState; // The state of the cell within the scroll view, can be left, right or middle

@property (nonatomic, strong) UIScrollView *cellScrollView;
@property (nonatomic, strong) SWUtilityButtonView *leftUtilityButtonsView, *rightUtilityButtonsView;
@property (nonatomic, strong) UIView *leftUtilityClipView, *rightUtilityClipView;
@property (nonatomic, strong) NSLayoutConstraint *leftUtilityClipConstraint, *rightUtilityClipConstraint;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

- (CGFloat)leftUtilityButtonsWidth;
- (CGFloat)rightUtilityButtonsWidth;
- (CGFloat)utilityButtonsPadding;

- (CGPoint)contentOffsetForCellState:(SWCellState)state;
- (void)updateCellState;

- (BOOL)shouldHighlight;

@end

@implementation YSCollectionViewCell{
    UIView *_contentCellView;
    BOOL layoutUpdating;
}

#pragma mark Initializers

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self initializer];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializer];
    }
    return self;
}

- (void)initializer
{
    layoutUpdating = NO;
    // Set up scroll view that will host our cell content
    self.cellScrollView = [[SWCellScrollView alloc] init];
    self.cellScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cellScrollView.delegate = self;
    self.cellScrollView.showsHorizontalScrollIndicator = NO;
    self.cellScrollView.scrollsToTop = NO;
    self.cellScrollView.scrollEnabled = YES;
    self.cellScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    
    _contentCellView = [[UIView alloc] init];
    [self.cellScrollView addSubview:_contentCellView];
    
    // iOS14 contentView 是懒加载 主动调用触发
    [self.contentView superview];
    
    // Add the cell scroll view to the cell
    UIView *contentViewParent = self;
    UIView *clipViewParent = self.cellScrollView;
    NSArray *cellSubviews = [contentViewParent subviews];
    [self insertSubview:self.cellScrollView atIndex:0];
    for (UIView *subview in cellSubviews)
    {
        [_contentCellView addSubview:subview];
    }
    
    // Set scroll view to perpetually have same frame as self. Specifying relative to superview doesn't work, since the latter UITableViewCellScrollView has different behaviour.
    [self addConstraints:@[
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0],
                           ]];
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTapped:)];
    self.tapGestureRecognizer.cancelsTouchesInView = NO;
    self.tapGestureRecognizer.delegate             = self;
    [self.cellScrollView addGestureRecognizer:self.tapGestureRecognizer];

    self.longPressGestureRecognizer = [[SWLongPressGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewPressed:)];
    self.longPressGestureRecognizer.cancelsTouchesInView = NO;
    self.longPressGestureRecognizer.minimumPressDuration = kLongPressMinimumDuration;
    self.longPressGestureRecognizer.delegate = self;
    [self.cellScrollView addGestureRecognizer:self.longPressGestureRecognizer];

    // Create the left and right utility button views, as well as vanilla UIViews in which to embed them.  We can manipulate the latter in order to effect clipping according to scroll position.
    // Such an approach is necessary in order for the utility views to sit on top to get taps, as well as allow the backgroundColor (and private UITableViewCellBackgroundView) to work properly.

    self.leftUtilityClipView = [[UIView alloc] init];
    self.leftUtilityClipConstraint = [NSLayoutConstraint constraintWithItem:self.leftUtilityClipView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
    self.leftUtilityButtonsView = [[SWUtilityButtonView alloc] initWithUtilityButtons:nil
                                                                           parentCell:self
                                                                utilityButtonSelector:@selector(leftUtilityButtonHandler:)];

    self.rightUtilityClipView = [[UIView alloc] initWithFrame:self.bounds];
    self.rightUtilityClipConstraint = [NSLayoutConstraint constraintWithItem:self.rightUtilityClipView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
    self.rightUtilityButtonsView = [[SWUtilityButtonView alloc] initWithUtilityButtons:nil
                                                                            parentCell:self
                                                                 utilityButtonSelector:@selector(rightUtilityButtonHandler:)];

    
    UIView *clipViews[] = { self.rightUtilityClipView, self.leftUtilityClipView };
    NSLayoutConstraint *clipConstraints[] = { self.rightUtilityClipConstraint, self.leftUtilityClipConstraint };
    UIView *buttonViews[] = { self.rightUtilityButtonsView, self.leftUtilityButtonsView };
    NSLayoutAttribute alignmentAttributes[] = { NSLayoutAttributeRight, NSLayoutAttributeLeft };
    
    for (NSUInteger i = 0; i < 2; ++i)
    {
        UIView *clipView = clipViews[i];
        NSLayoutConstraint *clipConstraint = clipConstraints[i];
        UIView *buttonView = buttonViews[i];
        NSLayoutAttribute alignmentAttribute = alignmentAttributes[i];
        
        clipConstraint.priority = UILayoutPriorityDefaultHigh;
        
        clipView.translatesAutoresizingMaskIntoConstraints = NO;
        clipView.clipsToBounds = YES;
        
        [clipViewParent addSubview:clipView];
        [self addConstraints:@[
                               // Pin the clipping view to the appropriate outer edges of the cell.
                               [NSLayoutConstraint constraintWithItem:clipView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:clipView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:clipView attribute:alignmentAttribute relatedBy:NSLayoutRelationEqual toItem:self attribute:alignmentAttribute multiplier:1.0 constant:0.0],
                               clipConstraint,
                               ]];
        
        [clipView addSubview:buttonView];
        [self addConstraints:@[
                               // Pin the button view to the appropriate outer edges of its clipping view.
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:clipView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:clipView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:alignmentAttribute relatedBy:NSLayoutRelationEqual toItem:clipView attribute:alignmentAttribute multiplier:1.0 constant:0.0],
                               
                               // Constrain the maximum button width so that at least a button's worth of contentView is left visible. (The button view will shrink accordingly.)
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.contentView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:-kUtilityButtonWidthDefault],
                               ]];
    }
    
}

static NSString * const kCollectionViewPanState = @"state";

- (void)removeOldTableViewPanObserver
{
    [_collectionViewPanGestureRecognizer removeObserver:self forKeyPath:kCollectionViewPanState];
}

- (void)dealloc
{
    _cellScrollView.delegate = nil;
    [self removeOldTableViewPanObserver];
}

- (void)setContainingCollectionView:(UICollectionView *)containingCollectionView
{
    [self removeOldTableViewPanObserver];
    
    _collectionViewPanGestureRecognizer = containingCollectionView.panGestureRecognizer;
    
    _containingCollectionView = containingCollectionView;
    
    if (containingCollectionView)
    {

        _containingCollectionView.directionalLockEnabled = YES;
        
        [self.tapGestureRecognizer requireGestureRecognizerToFail:_containingCollectionView.panGestureRecognizer];
        
        [_collectionViewPanGestureRecognizer addObserver:self forKeyPath:kCollectionViewPanState options:0 context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:kCollectionViewPanState] && object == _collectionViewPanGestureRecognizer)
    {
        if(_collectionViewPanGestureRecognizer.state == UIGestureRecognizerStateBegan || _collectionViewPanGestureRecognizer.state == UIGestureRecognizerStateFailed)
        {
            if(_cellState != kCellStateCenter)
            {
                if ([self.delegate respondsToSelector:@selector(swipeableCollectionCellShouldHideUtilityButtonsOnSwipe:)])
                {
                    if([self.delegate swipeableCollectionCellShouldHideUtilityButtonsOnSwipe:self])
                    {
                        [self hideUtilityButtonsAnimated:YES];
                    }
                }
            }
        }
    }
}

- (void)setLeftUtilityButtons:(NSArray *)leftUtilityButtons
{
    if (![_leftUtilityButtons sw_isEqualToButtons:leftUtilityButtons]) {
        _leftUtilityButtons = leftUtilityButtons;
        
        self.leftUtilityButtonsView.utilityButtons = leftUtilityButtons;

        [self.leftUtilityButtonsView layoutIfNeeded];
        [self layoutIfNeeded];
    }
}

- (void)setLeftUtilityButtons:(NSArray *)leftUtilityButtons WithButtonWidth:(CGFloat) width
{
    _leftUtilityButtons = leftUtilityButtons;
    
    [self.leftUtilityButtonsView setUtilityButtons:leftUtilityButtons WithButtonWidth:width];

    [self.leftUtilityButtonsView layoutIfNeeded];
    [self layoutIfNeeded];
}

- (void)setRightUtilityButtons:(NSArray *)rightUtilityButtons
{
    if (![_rightUtilityButtons sw_isEqualToButtons:rightUtilityButtons]) {
        _rightUtilityButtons = rightUtilityButtons;
        
        self.rightUtilityButtonsView.utilityButtons = rightUtilityButtons;

        [self.rightUtilityButtonsView layoutIfNeeded];
        [self layoutIfNeeded];
    }
}

- (void)setRightUtilityButtons:(NSArray *)rightUtilityButtons WithButtonWidth:(CGFloat) width
{
    _rightUtilityButtons = rightUtilityButtons;
    
    [self.rightUtilityButtonsView setUtilityButtons:rightUtilityButtons WithButtonWidth:width];

    [self.rightUtilityButtonsView layoutIfNeeded];
    [self layoutIfNeeded];
}

#pragma mark - UICollectionViewCell overrides

- (void)didMoveToSuperview
{
    self.containingCollectionView = nil;
    UIView *view = self.superview;
    
    do {
        if ([view isKindOfClass:[UICollectionView class]])
        {
            self.containingCollectionView = (UICollectionView *)view;
            break;
        }
    } while ((view = view.superview));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
        
    if (self.isHighlighted) {
        return;
    }
    
    // Offset the contentView origin so that it appears correctly w/rt the enclosing scroll view (to which we moved it).
    CGRect frame = self.contentView.frame;
    frame.origin.x = [self leftUtilityButtonsWidth];
    _contentCellView.frame = frame;
    
    self.cellScrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) + [self utilityButtonsPadding], CGRectGetHeight(self.frame));
    
    if (!self.cellScrollView.isTracking && !self.cellScrollView.isDecelerating && _cellState == kCellStateCenter)
    {
        self.cellScrollView.contentOffset = [self contentOffsetForCellState:_cellState];
    }
    
    [self updateCellState];
}

- (void)setFrame:(CGRect)frame
{
    layoutUpdating = YES;
    // Fix for new screen sizes
    // Initially, the cell is still 320 points wide
    // We need to layout our subviews again when this changes so our constraints clip to the right width
    BOOL widthChanged = (self.frame.size.width != frame.size.width);
    
    [super setFrame:frame];
    
    if (widthChanged)
    {
        [self layoutIfNeeded];
    }
    layoutUpdating = NO;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self hideUtilityButtonsAnimated:NO];
}

- (void)setSelected:(BOOL)selected {
 
    [self.leftUtilityButtonsView pushBackgroundColors];
    [self.rightUtilityButtonsView pushBackgroundColors];
    
    [super setSelected:selected];
    
    [self.leftUtilityButtonsView popBackgroundColors];
    [self.rightUtilityButtonsView popBackgroundColors];
}

- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout {
    [super didTransitionFromLayout:oldLayout toLayout:newLayout];
    
    [self layoutSubviews];

}

#pragma mark - Selection handling

- (BOOL)shouldHighlight
{
    BOOL shouldHighlight = YES;
    
    if ([self.containingCollectionView.delegate respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)])
    {
        NSIndexPath *cellIndexPath = [self.containingCollectionView indexPathForCell:self];
        
        shouldHighlight = [self.containingCollectionView.delegate collectionView:self.containingCollectionView shouldHighlightItemAtIndexPath:cellIndexPath];
    }
    
    return shouldHighlight;
}

- (void)scrollViewPressed:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan && !self.isHighlighted && self.shouldHighlight)
    {
        [self setHighlighted:YES];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        // Cell is already highlighted; clearing it temporarily seems to address visual anomaly.
        [self setHighlighted:NO];
        [self scrollViewTapped:gestureRecognizer];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        [self setHighlighted:NO];
    }
}

- (void)scrollViewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (_cellState == kCellStateCenter)
    {
        if (self.isSelected)
        {
            [self deselectCell];
        }
        else if (self.shouldHighlight) // UITableView refuses selection if highlight is also refused.
        {
            [self selectCell];
        }
    }
    else
    {
        // Scroll back to center
        [self hideUtilityButtonsAnimated:YES];
    }
}

- (void)selectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingCollectionView indexPathForCell:self];
        
        BOOL result = YES;
        if ([self.containingCollectionView.delegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)])
        {
             result = [self.containingCollectionView.delegate collectionView:self.containingCollectionView shouldSelectItemAtIndexPath:cellIndexPath];
        }

        
        if (result && cellIndexPath)
        {
            [self.containingCollectionView selectItemAtIndexPath:cellIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            
            if ([self.containingCollectionView.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)])
            {
                [self.containingCollectionView.delegate collectionView:self.containingCollectionView didSelectItemAtIndexPath:cellIndexPath];
            }
        }
    }
}

- (void)deselectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingCollectionView indexPathForCell:self];
        
        BOOL result = YES;
        if ([self.containingCollectionView.delegate respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)])
        {
             result = [self.containingCollectionView.delegate collectionView:self.containingCollectionView shouldDeselectItemAtIndexPath:cellIndexPath];
        }

        
        if (result && cellIndexPath)
        {
            [self.containingCollectionView deselectItemAtIndexPath:cellIndexPath animated:NO];
            
            if ([self.containingCollectionView.delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)])
            {
                [self.containingCollectionView.delegate collectionView:self.containingCollectionView didDeselectItemAtIndexPath:cellIndexPath];
            }
        }
    }
}

#pragma mark - Utility buttons handling

- (void)rightUtilityButtonHandler:(id)sender
{
    SWUtilityButtonTapGestureRecognizer *utilityButtonTapGestureRecognizer = (SWUtilityButtonTapGestureRecognizer *)sender;
    NSUInteger utilityButtonIndex = utilityButtonTapGestureRecognizer.buttonIndex;
    if ([self.delegate respondsToSelector:@selector(swipeableCollectionCell:didTriggerRightUtilityButtonWithIndex:)])
    {
        [self.delegate swipeableCollectionCell:self didTriggerRightUtilityButtonWithIndex:utilityButtonIndex];
    }
}

- (void)leftUtilityButtonHandler:(id)sender
{
    SWUtilityButtonTapGestureRecognizer *utilityButtonTapGestureRecognizer = (SWUtilityButtonTapGestureRecognizer *)sender;
    NSUInteger utilityButtonIndex = utilityButtonTapGestureRecognizer.buttonIndex;
    if ([self.delegate respondsToSelector:@selector(swipeableCollectionViewCell:didTriggerLeftUtilityButtonWithIndex:)])
    {
        [self.delegate swipeableCollectionViewCell:self didTriggerLeftUtilityButtonWithIndex:utilityButtonIndex];
    }
}

- (void)hideUtilityButtonsAnimated:(BOOL)animated
{
    if (_cellState != kCellStateCenter)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateCenter] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableCollectionCell:scrollingToState:)])
        {
            [self.delegate swipeableCollectionCell:self scrollingToState:kCellStateCenter];
        }
    }
}

- (void)showLeftUtilityButtonsAnimated:(BOOL)animated {
    if (_cellState != kCellStateLeft)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateLeft] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableCollectionCell:scrollingToState:)])
        {
            [self.delegate swipeableCollectionCell:self scrollingToState:kCellStateLeft];
        }
    }
}

- (void)showRightUtilityButtonsAnimated:(BOOL)animated {
    if (_cellState != kCellStateRight)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateRight] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableCollectionCell:scrollingToState:)])
        {
            [self.delegate swipeableCollectionCell:self scrollingToState:kCellStateRight];
        }
    }
}

- (BOOL)isUtilityButtonsHidden {
    return _cellState == kCellStateCenter;
}

#pragma mark - Geometry helpers

- (CGFloat)leftUtilityButtonsWidth
{
#if CGFLOAT_IS_DOUBLE
    return round(CGRectGetWidth(self.leftUtilityButtonsView.frame));
#else
    return roundf(CGRectGetWidth(self.leftUtilityButtonsView.frame));
#endif
}

- (CGFloat)rightUtilityButtonsWidth
{
#if CGFLOAT_IS_DOUBLE
    return round(CGRectGetWidth(self.rightUtilityButtonsView.frame));
#else
    return roundf(CGRectGetWidth(self.rightUtilityButtonsView.frame));
#endif
}

- (CGFloat)utilityButtonsPadding
{
#if CGFLOAT_IS_DOUBLE
    return round([self leftUtilityButtonsWidth] + [self rightUtilityButtonsWidth]);
#else
    return roundf([self leftUtilityButtonsWidth] + [self rightUtilityButtonsWidth]);
#endif
}

- (CGPoint)contentOffsetForCellState:(SWCellState)state
{
    CGPoint scrollPt = CGPointZero;
    
    switch (state)
    {
        case kCellStateCenter:
            scrollPt.x = [self leftUtilityButtonsWidth];
            break;
            
        case kCellStateRight:
            scrollPt.x = [self utilityButtonsPadding];
            break;
            
        case kCellStateLeft:
            scrollPt.x = 0;
            break;
    }
    
    return scrollPt;
}

- (void)updateCellState
{
    if(layoutUpdating == NO)
    {
        // Update the cell state according to the current scroll view contentOffset.
        for (NSNumber *numState in @[
                                     @(kCellStateCenter),
                                     @(kCellStateLeft),
                                     @(kCellStateRight),
                                     ])
        {
            SWCellState cellState = numState.integerValue;
            
            if (CGPointEqualToPoint(self.cellScrollView.contentOffset, [self contentOffsetForCellState:cellState]))
            {
                _cellState = cellState;
                break;
            }
        }
        
        // Update the clipping on the utility button views according to the current position.
        CGRect frame = [self.contentView.superview convertRect:self.contentView.frame toView:self];
        frame.size.width = CGRectGetWidth(self.frame);
        
        self.leftUtilityClipConstraint.constant = MAX(0, CGRectGetMinX(frame) - CGRectGetMinX(self.frame));
        self.rightUtilityClipConstraint.constant = MIN(0, CGRectGetMaxX(frame) - CGRectGetMaxX(self.frame));
        
        self.leftUtilityClipView.hidden = (self.leftUtilityClipConstraint.constant == 0);
        self.rightUtilityClipView.hidden = (self.rightUtilityClipConstraint.constant == 0);
        
        // Enable or disable the gesture recognizers according to the current mode.
        if (!self.cellScrollView.isDragging && !self.cellScrollView.isDecelerating)
        {
            self.tapGestureRecognizer.enabled = YES;
            self.longPressGestureRecognizer.enabled = (_cellState == kCellStateCenter);
        }
        else
        {
            self.tapGestureRecognizer.enabled = NO;
            self.longPressGestureRecognizer.enabled = NO;
        }        
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (velocity.x >= 0.5f)
    {
        if (_cellState == kCellStateLeft || !self.rightUtilityButtons || self.rightUtilityButtonsWidth == 0.0)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateRight;
        }
    }
    else if (velocity.x <= -0.5f)
    {
        if (_cellState == kCellStateRight || !self.leftUtilityButtons || self.leftUtilityButtonsWidth == 0.0)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateLeft;
        }
    }
    else
    {
        CGFloat leftThreshold = [self contentOffsetForCellState:kCellStateLeft].x + (self.leftUtilityButtonsWidth / 2);
        CGFloat rightThreshold = [self contentOffsetForCellState:kCellStateRight].x - (self.rightUtilityButtonsWidth / 2);
        
        if (targetContentOffset->x > rightThreshold)
        {
            _cellState = kCellStateRight;
        }
        else if (targetContentOffset->x < leftThreshold)
        {
            _cellState = kCellStateLeft;
        }
        else
        {
            _cellState = kCellStateCenter;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(swipeableCollectionCell:scrollingToState:)])
    {
        [self.delegate swipeableCollectionCell:self scrollingToState:_cellState];
    }
    
    if (_cellState != kCellStateCenter)
    {
        if ([self.delegate respondsToSelector:@selector(swipeableCollectionCellShouldHideUtilityButtonsOnSwipe:)])
        {
            for (YSCollectionViewCell *cell in [self.containingCollectionView visibleCells]) {
                if (cell != self && [cell isKindOfClass:[YSCollectionViewCell class]] && [self.delegate swipeableCollectionCellShouldHideUtilityButtonsOnSwipe:cell]) {
                    [cell hideUtilityButtonsAnimated:YES];
                }
            }
        }
    }
    
    *targetContentOffset = [self contentOffsetForCellState:_cellState];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x > [self leftUtilityButtonsWidth])
    {
        if ([self rightUtilityButtonsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableCollectionCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableCollectionCell:self canSwipeToState:kCellStateRight];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityButtonsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake([self leftUtilityButtonsWidth], 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    else
    {
        // Expose the left button view
        if ([self leftUtilityButtonsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableCollectionCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableCollectionCell:self canSwipeToState:kCellStateLeft];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityButtonsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake(0, 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    
    [self updateCellState];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableCollectionCell:didScroll:)]) {
        [self.delegate swipeableCollectionCell:self didScroll:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updateCellState];

    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableCollectionCellDidEndScrolling:)]) {
        [self.delegate swipeableCollectionCellDidEndScrolling:self];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateCellState];

    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableCollectionCellDidEndScrolling:)]) {
        [self.delegate swipeableCollectionCellDidEndScrolling:self];
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        self.tapGestureRecognizer.enabled = YES;
    }
    
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ((gestureRecognizer == self.containingCollectionView.panGestureRecognizer && otherGestureRecognizer == self.longPressGestureRecognizer)
        || (gestureRecognizer == self.longPressGestureRecognizer && otherGestureRecognizer == self.containingCollectionView.panGestureRecognizer))
    {
        // Return YES so the pan gesture of the containing table view is not cancelled by the long press recognizer
        return YES;
    }
    else
    {
        return NO;
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ![touch.view isKindOfClass:[UIControl class]];
}


@end
