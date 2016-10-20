//
//  CoverFlowPlainLayout.swift
//  CoverFlowPlainLayout
//
//  Created by LawLincoln on 2016/10/20.
//  Copyright © 2016年 Broccoli. All rights reserved.
//

import UIKit
open class CoverFlowPlainLayout: UICollectionViewLayout {
    
    public enum `DirectionType` { case horizontal, vertical }
    
    open private(set) var currentPage: Int = 0
    open var offset: UIOffset = .zero { didSet { invalidateLayout() } }
    open var direction: DirectionType = .horizontal
    fileprivate var layoutInfo: [String : UICollectionViewLayoutAttributes] = [:]
    fileprivate let offsetKeyPath = "collectionView.contentOffset"
    
    deinit { removeObserver(self, forKeyPath: offsetKeyPath) }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public convenience init(offset off: UIOffset, type: DirectionType) {
        self.init()
        offset = off
        direction = type
    }
    
    public override init() {
        super.init()
        setup()
    }

    //MARK:- override
    open override func prepare() {
        super.prepare()
        collectionView?.decelerationRate = 0
        guard let value = collectionView else { return }
        let sectionCount = value.numberOfSections
        var indexPath = IndexPath(item: 0, section: 0)
        var cellLayoutInfo: [String : UICollectionViewLayoutAttributes] = [:]
        for section in 0..<sectionCount {
            let itemCount = value.numberOfItems(inSection: section)
            for item in 0..<itemCount {
                indexPath = IndexPath(item: item, section: section)
                let itemAttributes = UICollectionViewLayoutAttributes.init(forCellWith: indexPath)
                itemAttributes.frame = contentFrameForCard(at: indexPath)
                cellLayoutInfo[indexPath.cfp_key] = itemAttributes
            }
        }
        layoutInfo = cellLayoutInfo
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutInfo[indexPath.cfp_key]
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var allAttributes: [UICollectionViewLayoutAttributes] = []
        for (_, info) in layoutInfo {
            if rect.intersects(info.frame) {
                allAttributes.append(info)
            }
        }
        return allAttributes
    }
    
    open override var collectionViewContentSize: CGSize {
        guard let value = collectionView else { return .zero }
        var size = CGSize(width: pageWidth * CGFloat(value.numberOfItems(inSection: 0)) + offset.horizontal,
                          height: value.bounds.height)
        if direction == .vertical {
            size = CGSize(width: value.bounds.width,
                          height: pageHeight * CGFloat(value.numberOfItems(inSection: 0)) + offset.vertical)
        }
        return size
    }
    
    open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        var point = proposedContentOffset
        guard let value = collectionView else { return point }
        let rawPageValue = direction == .vertical ? (value.contentOffset.y / pageHeight) : (value.contentOffset.x / pageWidth)
        let velocityValue = direction == .vertical ? velocity.y : velocity.x

        let _currentPage = velocityValue > 0 ? (floor(rawPageValue)) : (ceil(rawPageValue))
        let _nextPage = velocityValue > 0 ? (ceil(rawPageValue)) : (floor(rawPageValue))
        
        let pannedLessThanAPage = fabs(1 + _currentPage - rawPageValue) > 0.5
        let flicked = fabs(velocityValue) > flickVelocity
        let offsetValue = (direction == .vertical ? offset.vertical : offset.horizontal)/2
        let length = direction == .vertical ? pageHeight : pageWidth
        
        if pannedLessThanAPage && flicked {
            let xyValue = _nextPage * length
            if direction == .horizontal {
                point.x = xyValue
                if _nextPage < CGFloat(value.numberOfItems(inSection: 0)) {
                    point.x = max(point.x - offsetValue, 0)
                }
            } else {
                point.y = xyValue
                if _nextPage < CGFloat(value.numberOfItems(inSection: 0)) {
                    point.y = max(point.y - offsetValue, 0)
                }
            }
        } else {
            let r = round(rawPageValue)
            let p = r * length - offsetValue
            if direction == .horizontal { point.x = max(0, p) }
            else { point.y = max(0, p) }
        }
        return point
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let value = collectionView, keyPath == offsetKeyPath {
            let floatPage = value.contentOffset.x / pageWidth
            let newPage = Int(round(floatPage))
            if currentPage != newPage { currentPage = newPage }
        }
    }
    
}

fileprivate extension CoverFlowPlainLayout {
    
    func setup() {
        addObserver(self, forKeyPath: offsetKeyPath, options: .new, context: nil)
    }

    var cardWidth: CGFloat {
        guard let value = collectionView else { return 0 }
        return value.bounds.width - offset.horizontal * 2
    }
    
    var cardHeight: CGFloat {
        guard let value = collectionView else { return 0 }
        return value.bounds.height - offset.vertical * 2
    }
    
    var pageWidth: CGFloat { return cardWidth + offset.horizontal / 2 }
    
    var pageHeight: CGFloat { return cardHeight + offset.vertical / 2 }
    
    var flickVelocity: CGFloat { return 3 }
    
    func contentFrameForCard(at indexPath: IndexPath) -> CGRect {
        var rect = CGRect.zero
        guard let value = collectionView else { return rect }
        if direction == .horizontal {
            var posX = Int(offset.horizontal / 2 + pageWidth * CGFloat(indexPath.row))
            if value.numberOfItems(inSection: 0) == 1 {
                posX = Int(offset.horizontal + pageWidth * CGFloat(indexPath.row))
            }
            rect = CGRect(x: CGFloat(posX), y: offset.vertical, width: cardWidth, height: cardHeight)
        } else {
            let y = offset.vertical / 2 + pageHeight * CGFloat(indexPath.row)
            rect = CGRect(x: offset.horizontal, y: y, width: cardWidth, height: cardHeight)
        }
        return rect
    }
}

private extension IndexPath { var cfp_key: String { return "\(section)-\(item)" } }
