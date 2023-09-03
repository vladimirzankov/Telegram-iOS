//
//  ChatListOverlayTransition.swift
//  ChatListUI
//
//  Created by Занков Владимир Владимирович on 02.09.2023.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import TelegramCore
import ChatTitleView
import AccountContext

final class ChatListOverlayTransition {
    
    private var source: ContextContentSource
    
    private var sourceNode: ASDisplayNode
    
    private var snapshotView: UIView?
    
    private var animator: ConstantDisplayLinkAnimator?
    
    
    init(source: ContextContentSource, sourceNode: ASDisplayNode) {
        self.source = source
        self.sourceNode = sourceNode
    }
    
    func animateIn(contextView: UIView, springDuration: CGFloat, springDamping: CGFloat) -> Void {
        guard case let .controller(controllerSource) = source,
              let chatController = controllerSource.controller as? ChatController,
              let chatTitleView = chatController.findTitleView() as? ChatTitleView,
              let transitionInfo = controllerSource.transitionInfo(),
              let (chatListItemView, _) = transitionInfo.sourceNode(),
              let chatListItemNode = sourceNode.supernode as? ChatListItemNode,
              let snapshotView = chatListItemView.snapshotContentTree()
        else { return }
        
        snapshotView.backgroundColor = chatController.navigationBar?.backgroundColor
        snapshotView.layer.shadowColor = UIColor(white: 0, alpha: 0.2).cgColor
        snapshotView.layer.shadowOpacity = 1
        snapshotView.layer.shadowOffset = .zero
        snapshotView.layer.shadowRadius = 5
        snapshotView.frame = chatListItemView.convert(chatListItemView.bounds, to: contextView)
        self.snapshotView = snapshotView
        
        
        chatListItemView.isHidden = true
        contextView.addSubview(snapshotView)
        
        let sourceTitleView = chatListItemNode.titleNode.view
        
        if let sourceTitlePosition = sourceTitleView.superview?.convert(sourceTitleView.layer.position, to: chatTitleView.superview) {
            chatTitleView.layer.animateSpring(from: sourceTitlePosition.x as NSNumber, to: chatTitleView.layer.position.x as NSNumber, keyPath: "position.x", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        }
        
        if snapshotView.subviews.count > 1 {
            let avatarView = snapshotView.subviews[1]
            avatarView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1)
            avatarView.layer.animateScale(from: 1, to: 0.5, duration: 0.1)
        }
        
        snapshotView.layer.opacity = 0
        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2)
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
            guard let self, let snapshotView = self.snapshotView,
                  snapshotView.superview != nil,
                  let bar = chatController.navigationBar,
                  let barLayer = bar.view.layer.presentation(),
                  let snapshotTitleView = self.snapshotView,
                  let barTitleView = bar.titleView,
                  let barTitle = barTitleView.subviews.first?.subviews.first
            else {
                self?.animator?.invalidate()
                self?.animator = nil
                return
            }
            
            let newRect = barLayer.convert(barLayer.frame, to: contextView.layer)
            snapshotView.frame.size = newRect.size
            snapshotView.frame.origin.y = newRect.minY - 4.33
            
            if let parent = barTitle.superview,
               let parentLayer = parent.layer.presentation(),
               let childLayer = barTitle.layer.presentation() {
                let newCenter = parentLayer.convert(childLayer.frame, to: snapshotView.superview!.layer)
                snapshotTitleView.frame.origin.x = newCenter.minX - 80
            }
        })
        self.animator?.isPaused = false
    }
    
    func animateOut(contextView: UIView, transitionDuration: CGFloat) -> Void {
        guard case let .controller(controllerSource) = source,
              let snapshotView = self.snapshotView,
              snapshotView.superview != nil,
              let transitionInfo = controllerSource.transitionInfo(),
              let (sourceView, _) = transitionInfo.sourceNode(),
              let chatController = controllerSource.controller as? ChatController,
              let chatTitleView = chatController.findTitleView() as? ChatTitleView,
              let chatTitleLabel = chatTitleView.subviews.first?.subviews.first,
              let sourceTitleView = sourceView.subviews.first?.subviews.first
        else {
            self.snapshotView?.removeFromSuperview()
            return
        }
        
        let sourceTitleFrame = sourceTitleView.convert(sourceTitleView.bounds, to: chatTitleView.superview)
        let orig = chatTitleLabel.convert(chatTitleLabel.bounds.origin, to: chatTitleView)
        let endX2 = sourceTitleFrame.minX + (chatTitleView.frame.size.width / 2 - orig.x)
        chatTitleView.layer.animatePosition(from: chatTitleView.layer.position, to: CGPoint(x: endX2, y: chatTitleView.layer.position.y), duration: transitionDuration)
        let target = sourceView.convert(sourceView.bounds, to: contextView)
        
        let oldFrame = snapshotView.layer.frame
        snapshotView.layer.frame = target
        snapshotView.layer.animateFrame(from: oldFrame, to: target, duration: transitionDuration)
        
        snapshotView.layer.opacity = 1
        snapshotView.layer.animateAlpha(from: 0, to: 1, duration: transitionDuration, removeOnCompletion: true, completion: { _ in
            DispatchQueue.main.async {
                snapshotView.removeFromSuperview()
            }
        })
        
        if snapshotView.subviews.count > 1 {
            let avatarView = snapshotView.subviews[1]
            avatarView.layer.transform = CATransform3DMakeScale(1, 1, 1)
            avatarView.layer.animateScale(from: 0.1, to: 1, duration: transitionDuration)
        }
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
            guard let self, let snapshotView = self.snapshotView, snapshotView.superview != nil
            else {
                self?.animator?.invalidate()
                self?.animator = nil
                return
            }
            
            let chatTitleLabel = chatTitleView.titleTextNode.view
            
            if let parent = chatTitleLabel.superview,
               let parentLayer = parent.layer.presentation(),
               let childLayer = chatTitleLabel.layer.presentation() {
                let newCenter = parentLayer.convert(childLayer.frame, to: snapshotView.superview!.layer.presentation()!)
                
                snapshotView.frame.origin.x = newCenter.minX - 80
            }
        })
        self.animator?.isPaused = false
    }
}
