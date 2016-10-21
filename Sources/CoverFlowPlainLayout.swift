//
//  CoverFlowPlain.swift
//  CoverFlowLayout
//
//  Created by LawLincoln on 2016/10/20.
//  Copyright © 2016年 Broccoli. All rights reserved.
//

import UIKit
/**
 👊 实现 *CoverFlow* 效果的 UICollectionViewLayout
 
 👉 可以通过 CollectionView 的 contentInset 来对首个 item 实现定制化偏移
 
 🙆 horizontal 只支持 contentInset.left
 
 🙆 vertical 只支持 contentInset.top
 
 👻 实例
 ```
 private let layout = CoverFlowPlainLayout(itemSpacing: UIOffsetMake(10, 10), scroll: .horizontal)
 private var cv: UICollectionView!
 override func viewDidLoad() {
 super.viewDidLoad()
 cv = UICollectionView(frame: UIScreen.main.bounds, collectionViewLayout: layout)
 cv.delegate = self
 cv.dataSource = self
 cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: CellIdentifier)
 cv.contentInset.left = 10 // or cv.contentInset.left = 10 in vertical mode
 view.addSubview(cv)
 }
 ```
 
 */
open class CoverFlowPlainLayout: UICollectionViewLayout {
    
    public enum `DirectionType` { case horizontal, vertical }
    
    open private(set) var currentPage: Int = 0
    open var itemSpacing: UIOffset = .zero { didSet { invalidateLayout() } }
    open var direction: DirectionType = .horizontal { didSet { invalidateLayout() } }
    open var targetSection: Int = 0 { didSet { invalidateLayout() } }
    open var flickVelocity: CGFloat = 0.8
    fileprivate var inset: UIEdgeInsets { return collectionView?.contentInset ?? .zero }
    fileprivate var layoutInfo: [String : UICollectionViewLayoutAttributes] = [:]
    fileprivate let offsetKeyPath = "collectionView.contentOffset"
    
    deinit { removeObserver(self, forKeyPath: offsetKeyPath) }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public convenience init(itemSpacing space: UIOffset, scroll type: DirectionType) {
        self.init()
        itemSpacing = space
        direction = type
    }
    
    override public init() {
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
        var width = pageWidth * CGFloat(value.numberOfItems(inSection: 0)) + itemSpacing.horizontal / 2 + inset.left
        var height = value.bounds.height
        
        if direction == .vertical {
            width = value.bounds.width
            height = pageHeight * CGFloat(value.numberOfItems(inSection: 0)) + itemSpacing.vertical / 2 + inset.top
        }
        return CGSize(width: width, height: height)
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
        let offsetValue = (direction == .vertical ? itemSpacing.vertical : itemSpacing.horizontal)/2
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
        
        if direction == .horizontal {
            if point.x == 0 {
                point.x -= inset.left
            } else {
                point.x -= inset.left - itemSpacing.horizontal/2
            }
        } else {
            if point.y == 0 {
                point.y -= inset.top
            } else {
                point.y -= inset.top - itemSpacing.vertical/2
            }
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
        var offset: CGFloat = (itemSpacing.horizontal/2 + inset.left) * 2
        if direction == .vertical {
            offset = (itemSpacing.horizontal + inset.left) * 2
        }
        return value.bounds.width - offset
    }
    
    var cardHeight: CGFloat {
        guard let value = collectionView else { return 0 }
        var offset: CGFloat = (itemSpacing.vertical + inset.top) * 2
        if direction == .vertical {
            offset = (itemSpacing.vertical/2 + inset.top) * 2
        }
        return value.bounds.height - offset
    }
    
    var pageWidth: CGFloat { return cardWidth + itemSpacing.horizontal / 2 }
    
    var pageHeight: CGFloat { return cardHeight + itemSpacing.vertical / 2 }
    
    func contentFrameForCard(at indexPath: IndexPath) -> CGRect {
        var rect = CGRect.zero
        guard let value = collectionView else { return rect }
        if direction == .horizontal {
            var posX = Int(itemSpacing.horizontal / 2 + pageWidth * CGFloat(indexPath.row))
            if value.numberOfItems(inSection: 0) == 1 {
                posX = Int(itemSpacing.horizontal + pageWidth * CGFloat(indexPath.row))
            }
            rect = CGRect(x: CGFloat(posX), y: itemSpacing.vertical, width: cardWidth, height: cardHeight)
        } else {
            let y = itemSpacing.vertical / 2 + pageHeight * CGFloat(indexPath.row)
            rect = CGRect(x: itemSpacing.horizontal, y: y, width: cardWidth, height: cardHeight)
        }
        return rect
    }
}

private extension IndexPath { var cfp_key: String { return "\(section)-\(item)" } }
