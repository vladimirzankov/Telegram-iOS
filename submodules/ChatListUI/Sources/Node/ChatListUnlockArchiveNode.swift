//
//  ChatListUnlockArchiveNode.swift
//  ChatListUI
//
//  Created by Занков Владимир Владимирович on 02.09.2023.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AnimationUI
import ChatListHeaderComponent

final class ChatListUnlockArchiveNode: ASDisplayNode {
    
    private var backgroundGrayNode: ASDisplayNode!
    
    private var backgroundBlueNode: ASDisplayNode!
    
    private var backgroundBlueNodeMask: ASDisplayNode!
    
    private var capsuleNode: ASDisplayNode!
    
    private var arrowNode: AnimationNode!
    
    private var swipeTextNode: ImmediateTextNode!
    
    private var releaseTextNode: ImmediateTextNode!
    
    private var isOverscrolling = false
    
    private var isAnimating = false
    
    private var animator: ConstantDisplayLinkAnimator?
    
    private var swipeTextAnimation: TextAnimation?
    
    private var releaseTextAnimation: TextAnimation?
    
    private var iconAnimation: IconAnimation?
    
    var isAnimatingArchiveDisplay = false
    
    var isArchivePinned = false
    
    var overscrollHiddenChatItemsAllowed = false
    
    class TextAnimation {
        var xFrom: CGFloat = .zero
        var xTo: CGFloat = .zero
        var timeOffset: Double = 0
        var lastStep: CFTimeInterval = 0
        var opacityFrom: CGFloat = 0
        var opacityTo: CGFloat = 0
        var duration: CGFloat = 0
        
        init(
            xFrom: CGFloat,
            xTo: CGFloat,
            timeOffset: Double,
            lastStep: CFTimeInterval,
            opacityFrom: CGFloat,
            opacityTo: CGFloat,
            duration: CGFloat
        ) {
            self.xFrom = xFrom
            self.xTo = xTo
            self.timeOffset = timeOffset
            self.lastStep = lastStep
            self.opacityFrom = opacityFrom
            self.opacityTo = opacityTo
            self.duration = duration
        }
    }
    
    class IconAnimation {
        var yFrom: CGFloat = .zero
        var yTo: CGFloat = .zero
        var timeOffset: Double = 0
        var lastStep: CFTimeInterval = 0
        var duration: CGFloat = 0
        
        init(
            yFrom: CGFloat,
            yTo: CGFloat,
            timeOffset: Double,
            lastStep: CFTimeInterval,
            duration: CGFloat
        ) {
            self.yFrom = yFrom
            self.yTo = yTo
            self.timeOffset = timeOffset
            self.lastStep = lastStep
            self.duration = duration
        }
    }
    
    override init() {
        super.init()
        
        clipsToBounds = true
        
        self.backgroundGrayNode = ASImageNode()
        self.backgroundGrayNode?.setLayerBlock({
            let layer = CAGradientLayer()
            layer.colors = [UIColor(rgb: 0xb2b7bd).cgColor, UIColor(rgb: 0xd9dadf).cgColor]
            layer.locations = [0.0, 1.0]
            layer.startPoint = CGPoint(x: 0.0, y: 0.5)
            layer.endPoint = CGPoint(x: 1.0, y: 0.5)
            return layer
        })
        self.addSubnode(self.backgroundGrayNode)
        
        self.backgroundBlueNode = ASDisplayNode()
        self.backgroundBlueNode.setLayerBlock({
            let layer = CAGradientLayer()
            layer.colors = [UIColor(rgb: 0x3b82ea).cgColor, UIColor(rgb: 0x89c4f9).cgColor]
            layer.locations = [0.0, 1.0]
            layer.startPoint = CGPoint(x: 0.0, y: 0.5)
            layer.endPoint = CGPoint(x: 1.0, y: 0.5)
            return layer
        })
        self.addSubnode(self.backgroundBlueNode)
        
        self.backgroundBlueNodeMask = ASDisplayNode()
        self.backgroundBlueNodeMask.cornerRadius = 30
        self.backgroundBlueNodeMask.backgroundColor = .white
        backgroundBlueNodeMask.frame = CGRect(x: 10, y: 0, width: 60, height: 60)
        self.backgroundBlueNode.layer.mask = backgroundBlueNodeMask!.layer
        
        self.capsuleNode = ASDisplayNode()
        self.capsuleNode.backgroundColor = UIColor.init(white: 1, alpha: 0.5)
        self.capsuleNode.cornerRadius = 10
        self.addSubnode(self.capsuleNode)
        
        self.arrowNode = AnimationNode(animation: "anim_archiveicon3", colors: animationColorsDisabled, scale: UIScreen.main.scale)
        self.arrowNode.speed = 0
        self.arrowNode.setProgress(0)
        self.arrowNode.view.layer.transform = CATransform3DMakeRotation(Double.pi, 0.0, 0.0, 1.0)
        self.addSubnode(self.arrowNode)
        
        let greatestFiniteMagnitude = CGFloat.greatestFiniteMagnitude
        self.swipeTextNode = ImmediateTextNode()
        self.swipeTextNode.maximumNumberOfLines = 1
        self.swipeTextNode.attributedText = .init(string: "Swipe down for archive", font: Font.bold(16), textColor: .white)
        self.swipeTextNode.textAlignment = .center
        self.addSubnode(self.swipeTextNode)
        var titleSize = self.swipeTextNode.updateLayout(CGSize(width: greatestFiniteMagnitude, height: greatestFiniteMagnitude))
        self.swipeTextNode.frame.size = CGSize(width: titleSize.width, height: titleSize.height)
        
        self.releaseTextNode = ImmediateTextNode()
        self.releaseTextNode.maximumNumberOfLines = 1
        self.releaseTextNode.attributedText = .init(string: "Release for archive", font: Font.bold(16), textColor: .white)
        self.releaseTextNode.textAlignment = .center
        self.addSubnode(self.releaseTextNode)
        titleSize = self.releaseTextNode.updateLayout(CGSize(width: greatestFiniteMagnitude, height: greatestFiniteMagnitude))
        self.releaseTextNode.frame.size = CGSize(width: titleSize.width, height: titleSize.height)
    }
    
    func updateLayout(_ size: CGSize) {
        self.frame.size.width = size.width
        self.backgroundGrayNode.frame.size = CGSize(width: size.height, height: size.width)
        self.backgroundBlueNode.frame.size = CGSize(width: size.height, height: size.width)
    }
    
    func didBeginDragging() {
        
        self.backgroundGrayNode.isHidden = false
        self.backgroundGrayNode.frame.size.width = frame.width
        
        self.backgroundBlueNodeMask.view.layer.transform = CATransform3DMakeScale(0.33, 0.33, 1.0)
        
        self.arrowNode.view.layer.transform = CATransform3DMakeRotation(Double.pi, 0.0, 0.0, 1.0)
        self.arrowNode.setProgress(0)
        
        swipeTextNode.view.frame.origin.x = (self.frame.size.width - swipeTextNode.view.frame.width) / 2
        swipeTextNode.view.alpha = 1
        
        releaseTextNode.view.frame.origin.x = -(releaseTextNode.view.frame.width / 2)
        releaseTextNode.view.alpha = 0
    }
    
    func endedDragging() {
        self.isAnimatingArchiveDisplay = self.isOverscrolling
        
        if self.isAnimatingArchiveDisplay {
            self.backgroundGrayNode.isHidden = true
        }
        
        if isAnimatingArchiveDisplay {
            let oldPosition = self.backgroundBlueNodeMask.view.layer.position
            self.backgroundBlueNodeMask.view.layer.position = CGPoint(x: 40, y: 38)
            self.backgroundBlueNodeMask.view.layer.animatePosition(from: oldPosition, to: CGPoint(x: 40, y: 38), duration: 0.33)
            
            let big = frame.size.width / 15
            self.backgroundBlueNodeMask.view.layer.transform = CATransform3DMakeAffineTransform(.identity)
            self.backgroundBlueNodeMask.view.layer.animateScale(from: big, to: 1, duration: 0.33, completion: { _ in
                self.frame.size.height = 0
                self.isAnimatingArchiveDisplay = false
            })
        } else {
            self.backgroundBlueNodeMask.view.layer.transform = CATransform3DMakeScale(0.33, 0.33, 1.0)
        }
        
        if isAnimatingArchiveDisplay {
            var oldFrame = self.capsuleNode.layer.frame
            oldFrame.size.height -= 16
            var newFrame = oldFrame
            newFrame.origin.y = 38
            newFrame.size.height = 20

            self.capsuleNode.layer.frame = newFrame
            self.capsuleNode.layer.animateFrame(from: oldFrame, to: newFrame, duration: 0.25, completion: { _ in
                self.capsuleNode.isHidden = true
            })
        }
        
        if isAnimatingArchiveDisplay {
            arrowNode.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            arrowNode.layer.position.y -= 16
            var newArrowCenter = arrowNode.layer.position
            newArrowCenter.y = 38
            
            self.iconAnimation = IconAnimation(
                yFrom: arrowNode.layer.position.y,
                yTo: newArrowCenter.y,
                timeOffset: 0,
                lastStep: CACurrentMediaTime(),
                duration: 0.33
            )
            setupDisplayLinkAnimation()
        }
        
        if isAnimatingArchiveDisplay {
            self.releaseTextNode.alpha = 0
            self.releaseTextNode.view.layer.animateAlpha(from: 1, to: 0, duration: 0.33)
        }
    }
    
    func contentOffsetChanged(
        offset: ListViewVisibleContentOffset,
        selfController: ChatListControllerImpl?,
        listNode: ChatListNode
    ) {
        guard case let .known(value) = offset else { return }
        
        guard let controller = selfController, let chatListDisplayNode = controller.displayNode as? ChatListControllerNode, let navigationBarComponentView = chatListDisplayNode.navigationBarView.view as? ChatListNavigationBar.View, let _ = navigationBarComponentView.clippedScrollOffset
        else { return }
        
        let isDragging = listNode.isDragging
        var isOverscrolling = self.isOverscrolling
        if !isAnimating {
            isOverscrolling = self.overscrollHiddenChatItemsAllowed
        }
        
        
        let hiddenOffset = max(0, navigationBarComponentView.visibleHeight - navigationBarComponentView.frame.height)
        frame.origin.y = navigationBarComponentView.visibleHeight
        let _ = value + hiddenOffset
        
        if !(isAnimatingArchiveDisplay || listNode.hasItemsToBeRevealed()) || isArchivePinned {
            frame.size.height = 0
        } else {
            frame.size.height = isDragging || frame.size.height > 0 ? max(0, (listNode.itemNodeAtIndex(2)?.frame.origin.y ?? 0) - frame.origin.y) : 0
        }
        
        // capsuleNode
        if isDragging {
            capsuleNode.isHidden = false
        }
        if !isAnimatingArchiveDisplay {
            let capsuleHeight = max(frame.size.height - 16, 20)
            capsuleNode.frame = CGRect(x: 30, y: frame.size.height - capsuleHeight - 8, width: 20, height: capsuleHeight)
        }
        
        var isGoingToAnimate = false
        
        // arrowNode
        if !isAnimatingArchiveDisplay {
            arrowNode.setProgress(0)
            arrowNode.anchorPoint = CGPoint(x: 0.5, y: 0.56)
            
            arrowNode.view.layer.position = CGPoint(x: capsuleNode.frame.midX, y: capsuleNode.frame.maxY - capsuleNode.frame.width / 2)
            arrowNode.view.layer.bounds.size = CGSize(width: 62, height: 62)
            
            if self.isOverscrolling != isOverscrolling && !isAnimating {
                isGoingToAnimate = true
                if isOverscrolling {
                    self.arrowNode.view.layer.transform = CATransform3DMakeAffineTransform(.identity)
                    self.arrowNode.layer.animateRotation(from: Double.pi, to: 0, duration: 0.25, completion: { _ in
                        self.isAnimating = false
                    })
                    self.arrowNode.setColors(colors: animationColorsEnabled)
                    
                } else {
                    self.arrowNode.view.layer.transform = CATransform3DMakeRotation(Double.pi, 0.0, 0.0, 1.0)
                    self.arrowNode.layer.animateRotation(from: 0, to: Double.pi, duration: 0.25, completion: { _ in
                        self.isAnimating = false
                        self.arrowNode.setColors(colors: self.animationColorsDisabled)
                    })
                }
            }
        }
        
        // backgroundGrayNode
        if isDragging {
            backgroundGrayNode.isHidden = false
        }
        
        // backgroundBlueNodeMask
        if !isAnimatingArchiveDisplay {
            backgroundBlueNodeMask.frame.origin.y = (capsuleNode.frame.maxY - 10) - 30
            backgroundBlueNodeMask.frame.origin.x = capsuleNode.frame.midX - 30
        } else {
            backgroundBlueNodeMask.frame.origin.y = 8
        }
        
        if isDragging {
            if self.isOverscrolling != isOverscrolling && !isAnimating {
                isGoingToAnimate = true
                
                let big = frame.size.width / 15
                
                if isOverscrolling {
                    self.backgroundBlueNodeMask.view.layer.transform = CATransform3DMakeScale(big, big, 1.0)
                    backgroundBlueNodeMask.view.layer.animateScale(from: 0.33, to: big, duration: 0.20)
                } else {
                    self.backgroundBlueNodeMask.view.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
                    backgroundBlueNodeMask.view.layer.animateScale(from: big, to: 0.33, duration: 0.20)
                }
            }
        }
        
        // swipeTextNode
        swipeTextNode.view.frame.origin.y = frame.size.height - swipeTextNode.view.frame.height - 8
        if !isAnimating && isDragging && self.isOverscrolling != isOverscrolling  {
            isGoingToAnimate = true
            if isOverscrolling {
                let old = swipeTextNode.layer.position
                let new = CGPoint(x: frame.size.width + swipeTextNode.layer.frame.width / 2, y: old.y)
                self.swipeTextAnimation = TextAnimation(
                    xFrom: old.x,
                    xTo: new.x,
                    timeOffset: 0,
                    lastStep: CACurrentMediaTime(),
                    opacityFrom: 1,
                    opacityTo: 0,
                    duration: 0.25
                )
            }
            if !isOverscrolling {
                let old = swipeTextNode.layer.position
                let new = CGPoint(x: frame.center.x, y: old.y)
                self.swipeTextAnimation = TextAnimation(
                    xFrom: old.x,
                    xTo: new.x,
                    timeOffset: 0,
                    lastStep: CACurrentMediaTime(),
                    opacityFrom: 0,
                    opacityTo: 1,
                    duration: 0.25
                )
            }
        }
        
        // releaseTextNode
        releaseTextNode.view.frame.origin.y = frame.size.height - releaseTextNode.view.frame.height - 8
        if !isAnimating && isDragging && self.isOverscrolling != isOverscrolling  {
            isGoingToAnimate = true
            if !isOverscrolling {
                let old = releaseTextNode.layer.position
                let new = CGPoint(x: -(releaseTextNode.layer.frame.width / 2), y: old.y)
                self.releaseTextAnimation = TextAnimation(
                    xFrom: old.x,
                    xTo: new.x,
                    timeOffset: 0,
                    lastStep: CACurrentMediaTime(),
                    opacityFrom: 1,
                    opacityTo: 0,
                    duration: 0.25
                )
            }
            
            if isOverscrolling {
                let old = releaseTextNode.layer.position
                let new = CGPoint(x: frame.center.x, y: old.y)
                self.releaseTextAnimation = TextAnimation(
                    xFrom: old.x,
                    xTo: new.x,
                    timeOffset: 0,
                    lastStep: CACurrentMediaTime(),
                    opacityFrom: 0,
                    opacityTo: 1,
                    duration: 0.25
                )
            }
        }
        
        if isGoingToAnimate {
            setupDisplayLinkAnimation()
        }
        
        self.isAnimating = isGoingToAnimate
        self.isOverscrolling = isOverscrolling
    }
    
    private func setupDisplayLinkAnimation() {
        if self.swipeTextAnimation != nil || self.releaseTextAnimation != nil || self.iconAnimation != nil {
            
            if let animator = self.animator {
                animator.invalidate()
                self.animator = nil
            }
            self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let self else { return }
                
                let thisStep = CACurrentMediaTime()
                if let swipeTextAnimation {
                    let stepDuration = thisStep - self.swipeTextAnimation!.lastStep
                    swipeTextAnimation.lastStep = thisStep
                    
                    swipeTextAnimation.timeOffset = min(swipeTextAnimation.timeOffset + stepDuration, swipeTextAnimation.duration)
                    let time = listViewAnimationCurveSystem(swipeTextAnimation.timeOffset / swipeTextAnimation.duration)
                    let value = (swipeTextAnimation.xTo - swipeTextAnimation.xFrom) * time + swipeTextAnimation.xFrom
                    self.swipeTextNode.position.x = value
                    self.swipeTextNode.view.layer.opacity = Float((swipeTextAnimation.opacityTo - swipeTextAnimation.opacityFrom) * time + swipeTextAnimation.opacityFrom)
                    
                    if swipeTextAnimation.timeOffset >= swipeTextAnimation.duration {
                        self.swipeTextAnimation = nil
                    }
                }
                
                if let releaseTextAnimation {
                    let stepDuration = thisStep - releaseTextAnimation.lastStep
                    releaseTextAnimation.lastStep = thisStep
                    
                    releaseTextAnimation.timeOffset = min(releaseTextAnimation.timeOffset + stepDuration, releaseTextAnimation.duration)
                    let time = listViewAnimationCurveSystem(releaseTextAnimation.timeOffset / releaseTextAnimation.duration)
                    let value = (releaseTextAnimation.xTo - releaseTextAnimation.xFrom) * time + releaseTextAnimation.xFrom
                    self.releaseTextNode.position.x = value
                    self.releaseTextNode.view.layer.opacity = Float((releaseTextAnimation.opacityTo - releaseTextAnimation.opacityFrom) * time + releaseTextAnimation.opacityFrom)
                    
                    if releaseTextAnimation.timeOffset >= releaseTextAnimation.duration {
                        self.releaseTextAnimation = nil
                    }
                }
                
                if let iconAnimation {
                    let stepDuration = thisStep - self.iconAnimation!.lastStep
                    iconAnimation.lastStep = thisStep
                    
                    iconAnimation.timeOffset = min(iconAnimation.timeOffset + stepDuration, iconAnimation.duration)
                    
                    let time = listViewAnimationCurveFromAnimationOptions(animationOptions: .curveEaseOut)(iconAnimation.timeOffset / iconAnimation.duration)
                    
                    let value = (iconAnimation.yTo - iconAnimation.yFrom) * time + iconAnimation.yFrom
                    self.arrowNode.position.y = value
                    
                    self.arrowNode.setProgress(time / 5)
                    
                    if iconAnimation.timeOffset >= iconAnimation.duration {
                        self.iconAnimation = nil
                        
                    }
                }
            })
            animator?.isPaused = false
        } else if let animator = self.animator {
            self.animator = nil
            animator.invalidate()
        }
    }
    
    private let darkGray = UIColor(rgb: 0xb2b7bd)
    private let lightGray = UIColor(rgb: 0xd9dadf)
    private let darkBlue = UIColor(rgb: 0x3b82ea)
    private let lightBlue = UIColor(rgb: 0x89c4f9)
    
    private let animationColorsDisabled: [String: UIColor] = [
        "Box.box1.Fill 1": .white,
        "Cap.cap1.Fill 1": .white,
        "Cap.cap2.Fill 1": .white,
        "Arrow 1.Arrow 1.Stroke 1": UIColor(rgb: 0xb2b7bd),
        "Arrow 2.Arrow 2.Stroke 1": UIColor(rgb: 0xb2b7bd)
    ]
    
    private let animationColorsEnabled: [String: UIColor] = [
        "Box.box1.Fill 1": .white,
        "Cap.cap1.Fill 1": .white,
        "Cap.cap2.Fill 1": .white,
        "Arrow 1.Arrow 1.Stroke 1": UIColor(rgb: 0x3b82ea),
        "Arrow 2.Arrow 2.Stroke 1": UIColor(rgb: 0x3b82ea)
    ]
}
