//
//  UICollectionViewWaterfallLayout.m
//
//  Created by Nelson on 12/11/19.
//  Copyright (c) 2012 Nelson Tai. All rights reserved.
//

#import "CHTCollectionViewWaterfallLayout.h"

@interface CHTCollectionViewWaterfallLayout ()
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) CGFloat interitemSpacing;
@property (nonatomic, strong) NSMutableArray *columnHeights; // height for each column
@property (nonatomic, strong) NSMutableArray *itemAttributes; // attributes for each item
@property (nonatomic, strong) NSMutableArray *unionRects;
@end

@implementation CHTCollectionViewWaterfallLayout

const int unionSize = 20;

#pragma mark - Accessors
- (void)setColumnCount:(NSUInteger)columnCount {
	if (_columnCount != columnCount) {
		_columnCount = columnCount;
		[self invalidateLayout];
	}
}

- (void)setItemWidth:(CGFloat)itemWidth {
	if (_itemWidth != itemWidth) {
		_itemWidth = itemWidth;
		[self invalidateLayout];
	}
}

- (void)setSectionInset:(UIEdgeInsets)sectionInset {
	if (!UIEdgeInsetsEqualToEdgeInsets(_sectionInset, sectionInset)) {
		_sectionInset = sectionInset;
		[self invalidateLayout];
	}
}
- (void)setHeaderReferenceHeight:(CGFloat)headerReferenceHeight {
    if (_headerReferenceHeight != headerReferenceHeight) {
        _headerReferenceHeight = headerReferenceHeight;
        [self invalidateLayout];
    }
}

#pragma mark - Init
- (void)commonInit {
	_columnCount = 2;
	_itemWidth = 140.0f;
	_sectionInset = UIEdgeInsetsZero;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)init {
	self = [super init];
	if (self) {
		[self commonInit];
	}
	return self;
}

#pragma mark - Life cycle
- (void)dealloc {
	[_columnHeights removeAllObjects];
	_columnHeights = nil;
    
	[_itemAttributes removeAllObjects];
	_itemAttributes = nil;
}

#pragma mark - Methods to Override
- (void)prepareLayout {
	[super prepareLayout];
    
	NSInteger idx = 0;
	_itemCount = [[self collectionView] numberOfItemsInSection:0];
    
	//NSAssert(_columnCount > 1, @"columnCount for UICollectionViewWaterfallLayout should be greater than 1.");
	// for one column.
    if(_columnCount > 1){
        CGFloat width = self.collectionView.frame.size.width - _sectionInset.left - _sectionInset.right;
        _interitemSpacing = floorf((width - _columnCount * _itemWidth) / (_columnCount - 1));
    }else {
        _interitemSpacing = (_sectionInset.top + _sectionInset.bottom) * 0.5;
    }
    
	_itemAttributes = [NSMutableArray arrayWithCapacity:_itemCount];
	_columnHeights = [NSMutableArray arrayWithCapacity:_columnCount];
    CGFloat startHeight = _sectionInset.top + [self heightForHeaderInSection:0]; // todo fix for multi section
	for (idx = 0; idx < _columnCount; idx++) {
		[_columnHeights addObject:@(startHeight)];
	}
    
	// Item will be put into shortest column.
	for (idx = 0; idx < _itemCount; idx++) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
		CGFloat itemHeight = [self.delegate collectionView:self.collectionView
		                                            layout:self
		                          heightForItemAtIndexPath:indexPath];
		NSUInteger columnIndex = [self shortestColumnIndex];
		CGFloat xOffset = _sectionInset.left + (_itemWidth + _interitemSpacing) * columnIndex;
		CGFloat yOffset = [(_columnHeights[columnIndex])floatValue];
        
		UICollectionViewLayoutAttributes *attributes =
        [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
		attributes.frame = CGRectMake(xOffset, yOffset, self.itemWidth, itemHeight);
		[_itemAttributes addObject:attributes];
		_columnHeights[columnIndex] = @(yOffset + itemHeight + _interitemSpacing);
	}
    
	idx = 0;
	_unionRects = [NSMutableArray array];
	while (idx < _itemCount) {
		CGRect rect1 = ((UICollectionViewLayoutAttributes *)_itemAttributes[idx]).frame;
		idx = MIN(idx + unionSize, _itemCount) - 1;
		CGRect rect2 = ((UICollectionViewLayoutAttributes *)_itemAttributes[idx]).frame;
		[_unionRects addObject:[NSValue valueWithCGRect:CGRectUnion(rect1, rect2)]];
		idx++;
	}
}

- (CGSize)collectionViewContentSize {
	if (self.itemCount == 0) {
		return CGSizeZero;
	}
    
	CGSize contentSize = self.collectionView.frame.size;
	NSUInteger columnIndex = [self longestColumnIndex];
	CGFloat height = [self.columnHeights[columnIndex] floatValue];
	contentSize.height = height - self.interitemSpacing + self.sectionInset.bottom;
	return contentSize;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path {
	return (self.itemAttributes)[path.item];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
	NSInteger i;
	NSInteger begin = 0, end = self.unionRects.count;
	NSMutableArray *attrs = [NSMutableArray array];
    
    UICollectionViewLayoutAttributes *headerAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    if (headerAttributes && CGRectIntersectsRect(rect, headerAttributes.frame)) {
        [attrs addObject:headerAttributes];
    }
    
	for (i = 0; i < self.unionRects.count; i++) {
		if (CGRectIntersectsRect(rect, [self.unionRects[i] CGRectValue])) {
			begin = i * unionSize;
			break;
		}
	}
	for (i = self.unionRects.count - 1; i >= 0; i--) {
		if (CGRectIntersectsRect(rect, [self.unionRects[i] CGRectValue])) {
			end = MIN((i + 1) * unionSize, self.itemAttributes.count);
			break;
		}
	}
	for (i = begin; i < end; i++) {
		UICollectionViewLayoutAttributes *attr = self.itemAttributes[i];
		if (CGRectIntersectsRect(rect, attr.frame)) {
			[attrs addObject:attr];
		}
	}
	return [attrs copy];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
	return NO;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (![kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return nil;
    }
    CGFloat referenceHeight = [self heightForHeaderInSection:indexPath.section];
    if (ABS(referenceHeight)<=0.1) {
        return nil;
    }
    
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:[NSIndexPath indexPathForItem:0 inSection:indexPath.section]];
    attributes.frame = CGRectMake(0, 0, CGRectGetWidth(self.collectionView.bounds), referenceHeight);
    return attributes;
}

#pragma mark - Private Methods

// Find out shortest column.
- (NSUInteger)shortestColumnIndex {
	__block NSUInteger index = 0;
	__block CGFloat shortestHeight = MAXFLOAT;
    
	[self.columnHeights enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
	    CGFloat height = [obj floatValue];
	    if (height < shortestHeight) {
	        shortestHeight = height;
	        index = idx;
		}
	}];
    
	return index;
}

// Find out longest column.
- (NSUInteger)longestColumnIndex {
	__block NSUInteger index = 0;
	__block CGFloat longestHeight = 0;
    
	[self.columnHeights enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
	    CGFloat height = [obj floatValue];
	    if (height > longestHeight) {
	        longestHeight = height;
	        index = idx;
		}
	}];
    
	return index;
}

- (CGFloat)heightForHeaderInSection:(NSUInteger)section {
    CGFloat referenceHeight = 0.0;
    if ([self.delegate respondsToSelector:@selector(collectionView:layout:referenceHeightForHeaderInSection:)]) {
        referenceHeight = [self.delegate collectionView:self.collectionView layout:self referenceHeightForHeaderInSection:section];
    } else {
        referenceHeight = self.headerReferenceHeight;
    }
    return referenceHeight;
}

@end
