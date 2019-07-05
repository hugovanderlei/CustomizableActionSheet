//
//  CustomizableActionSheet.swift
//  CustomizableActionSheet
//
//  Created by Ryuta Kibe on 2015/12/22.
//  Copyright 2015 blk. All rights reserved.
//

import UIKit

@objc public enum CustomizableActionSheetItemType: Int {
    case button
    case view
}

// Can't define CustomizableActionSheetItem as struct because Obj-C can't see struct definition.
public class CustomizableActionSheetItem: NSObject {
    
    // MARK: - Public properties
    public var type: CustomizableActionSheetItemType = .button
    public var height: CGFloat = CustomizableActionSheetItem.kDefaultHeight
    public static let kDefaultHeight: CGFloat = 44
    
    // type = .View
    public var view: UIView?
    
    // type = .Button
    public var label: String?
    public var textColor: UIColor = UIColor(red: 0, green: 0.47, blue: 1.0, alpha: 1.0)
    public var backgroundColor: UIColor = UIColor.white
    public var font: UIFont? = nil
    public var selectAction: ((_ actionSheet: CustomizableActionSheet) -> Void)? = nil
    
    // MARK: - Private properties
    fileprivate var element: UIView? = nil
    
    public convenience init(type: CustomizableActionSheetItemType,
                            height: CGFloat = CustomizableActionSheetItem.kDefaultHeight) {
        self.init()
        
        self.type = type
        self.height = height
    }
}

private class ActionSheetItemView: UIView {
    var subview: UIView?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.setting()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setting()
    }
    
    init() {
        super.init(frame: CGRect.zero)
        self.setting()
    }
    
    func setting() {
        self.clipsToBounds = true
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        self.subview = view
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let subview = self.subview {
            subview.frame = self.bounds
        }
    }
}

@objc public enum CustomizableActionSheetPosition: Int {
    case bottom
    case top
}

public class CustomizableActionSheet: NSObject {
    
    // MARK: - Private properties
    
    private static var actionSheets = [CustomizableActionSheet]()
    public static let marginSide: CGFloat = 0
    public static let itemInterval: CGFloat = 0
    public static let marginTop: CGFloat = 20
    private var items: [CustomizableActionSheetItem]?
    public let maskView = UIView()
    public var itemContainerView = UIView()
    private var closeBlock: (() -> Void)?
    
    // MARK: - Public properties
    
    public var defaultCornerRadius: CGFloat = 0
    public var position: CustomizableActionSheetPosition = .bottom
    
    public func showInView(_ targetView: UIView, items: [CustomizableActionSheetItem], closeBlock: (() -> Void)? = nil) {
        // Save instance to reaction until closing this sheet
        CustomizableActionSheet.actionSheets.append(self)
        
        let targetBounds = targetView.bounds
        
        // Save closeBlock
        self.closeBlock = closeBlock
        
        // mask view
        let maskViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(CustomizableActionSheet.maskViewWasTapped))
        self.maskView.addGestureRecognizer(maskViewTapGesture)
        self.maskView.frame = targetBounds
        self.maskView.backgroundColor = UIColor.init(white: 1, alpha: 0.7)
        targetView.addSubview(self.maskView)
        
        // set items
        for subview in self.itemContainerView.subviews {
            subview.removeFromSuperview()
        }
        var currentPosition: CGFloat = 0
        let safeAreaTop: CGFloat
        let safeAreaBottom: CGFloat
        if #available(iOS 11.0, *) {
            safeAreaTop = targetView.safeAreaInsets.top
            safeAreaBottom = targetView.safeAreaInsets.bottom
        } else {
            safeAreaTop = CustomizableActionSheet.marginTop
            safeAreaBottom = 0
        }
        var availableHeight = targetBounds.height - safeAreaTop - safeAreaBottom
        
        // Calculate height of items
        for item in items {
            availableHeight = availableHeight - item.height - CustomizableActionSheet.itemInterval
        }
        
        for item in items {
            // Apply height of items
            if availableHeight < 0 {
                let reduceNum = min(item.height, -availableHeight)
                item.height -= reduceNum
                availableHeight += reduceNum
                
                if item.height <= 0 {
                    availableHeight += CustomizableActionSheet.itemInterval
                    continue
                }
            }
            
            // Add views
            switch (item.type) {
            case .button:
                let button = UIButton()
                button.layer.cornerRadius = defaultCornerRadius
                button.frame = CGRect(
                    x: CustomizableActionSheet.marginSide,
                    y: currentPosition,
                    width: targetBounds.width - (CustomizableActionSheet.marginSide * 2),
                    height: item.height)
                button.setTitle(item.label, for: UIControl.State())
                button.backgroundColor = item.backgroundColor
                button.setTitleColor(item.textColor, for: UIControl.State())
                if let font = item.font {
                    button.titleLabel?.font = font
                }
                if let _ = item.selectAction {
                    button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(CustomizableActionSheet.buttonWasTapped(_:))))
                }
                item.element = button
                self.itemContainerView.addSubview(button)
                currentPosition = currentPosition + item.height + CustomizableActionSheet.itemInterval
            case .view:
                if let view = item.view {
                    let containerView = ActionSheetItemView(frame: CGRect(
                        x: CustomizableActionSheet.marginSide,
                        y: currentPosition,
                        width: targetBounds.width - (CustomizableActionSheet.marginSide * 2),
                        height: item.height))
                    containerView.layer.cornerRadius = defaultCornerRadius
                    containerView.addSubview(view)
                    view.frame = view.bounds
                    self.itemContainerView.addSubview(containerView)
                    item.element = view
                    currentPosition = currentPosition + item.height + CustomizableActionSheet.itemInterval
                }
            }
        }
        
        let positionX: CGFloat = 0
        var positionY: CGFloat = targetBounds.minY + targetBounds.height - currentPosition - safeAreaBottom
        var moveY: CGFloat = positionY
        if self.position == .top {
            positionY = CustomizableActionSheet.itemInterval
            moveY = -currentPosition
        }
        self.itemContainerView.frame = CGRect(
            x: positionX,
            y: positionY,
            width: targetBounds.width,
            height: currentPosition)
        self.items = items
        
        // Show animation
        self.maskView.alpha = 0
        targetView.addSubview(self.itemContainerView)
        self.itemContainerView.transform = CGAffineTransform(translationX: 0, y: moveY)
        UIView.animate(withDuration: 0.4,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 0,
                       options: .curveEaseOut,
                       animations: { () -> Void in
                        self.maskView.alpha = 1
                        self.itemContainerView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    public func insetShadow(){
        self.itemContainerView.layer.shadowColor = UIColor.black.cgColor
        self.itemContainerView.layer.shadowOffset = CGSize(width: 3, height: 0)
        self.itemContainerView.layer.shadowRadius = 7.5
        self.itemContainerView.layer.shadowOpacity = 0.13
    }
    
    public func dismiss() {
        guard let targetView = self.itemContainerView.superview else {
            return
        }
        
        // Hide animation
        self.maskView.alpha = 1
        var moveY: CGFloat = targetView.bounds.height - self.itemContainerView.frame.origin.y
        if self.position == .top {
            moveY = -self.itemContainerView.frame.height
        }
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 0,
                       options: .curveEaseOut,
                       animations: { () -> Void in
                        self.maskView.alpha = 0
                        self.itemContainerView.transform = CGAffineTransform(translationX: 0, y: moveY)
        }) { (result: Bool) -> Void in
            // Remove views
            self.itemContainerView.removeFromSuperview()
            self.maskView.removeFromSuperview()
            
            // Remove this instance
            for i in 0 ..< CustomizableActionSheet.actionSheets.count {
                if CustomizableActionSheet.actionSheets[i] == self {
                    CustomizableActionSheet.actionSheets.remove(at: i)
                    break
                }
            }
            
            self.closeBlock?()
        }
    }
    
    // MARK: - Private methods
    
    @objc private func maskViewWasTapped() {
        self.dismiss()
    }
    
    @objc private func buttonWasTapped(_ sender: AnyObject) {
        guard let items = self.items else {
            return
        }
        for item in items {
            guard
                let element = item.element,
                let gestureRecognizer = sender as? UITapGestureRecognizer else {
                    continue
            }
            if element == gestureRecognizer.view {
                item.selectAction?(self)
            }
        }
    }
}
