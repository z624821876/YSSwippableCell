//
//  YSCollectionViewCell.h
//  SWTableViewCell
//
//  Created by yu on 2021/3/30.
//  Copyright © 2021 Chris Wendel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SWHeader.h"
#import "SWCellScrollView.h"
#import "SWLongPressGestureRecognizer.h"
#import "SWUtilityButtonTapGestureRecognizer.h"
#import "NSMutableArray+SWUtilityButtons.h"

NS_ASSUME_NONNULL_BEGIN

@class YSCollectionViewCell;

@protocol SWCollectionViewCellDelegate <NSObject>

@optional
- (void)swipeableCollectionViewCell:(YSCollectionViewCell *)cell didTriggerLeftUtilityButtonWithIndex:(NSInteger)index;
- (void)swipeableCollectionCell:(YSCollectionViewCell *)cell didTriggerRightUtilityButtonWithIndex:(NSInteger)index;
- (void)swipeableCollectionCell:(YSCollectionViewCell *)cell scrollingToState:(SWCellState)state;
- (BOOL)swipeableCollectionCellShouldHideUtilityButtonsOnSwipe:(YSCollectionViewCell *)cell;
- (BOOL)swipeableCollectionCell:(YSCollectionViewCell *)cell canSwipeToState:(SWCellState)state;
- (void)swipeableCollectionCellDidEndScrolling:(YSCollectionViewCell *)cell;
- (void)swipeableCollectionCell:(YSCollectionViewCell *)cell didScroll:(UIScrollView *)scrollView;

@end

@interface YSCollectionViewCell : UICollectionViewCell

@property (nonatomic, copy) NSArray *leftUtilityButtons;
@property (nonatomic, copy) NSArray *rightUtilityButtons;

@property (nonatomic, weak) id <SWCollectionViewCellDelegate> delegate;

- (void)setRightUtilityButtons:(NSArray *)rightUtilityButtons WithButtonWidth:(CGFloat) width;
- (void)setLeftUtilityButtons:(NSArray *)leftUtilityButtons WithButtonWidth:(CGFloat) width;
- (void)hideUtilityButtonsAnimated:(BOOL)animated;
- (void)showLeftUtilityButtonsAnimated:(BOOL)animated;
- (void)showRightUtilityButtonsAnimated:(BOOL)animated;

- (BOOL)isUtilityButtonsHidden;

@end

NS_ASSUME_NONNULL_END
