import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import SolidRoundedButtonNode
import TelegramPresentationData
import TelegramUIPreferences
import TelegramNotices
import PresentationDataUtils
import AnimationUI
import MergeLists
import MediaResources
import StickerResources
import WallpaperResources
import TooltipUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import WallpaperBackgroundNode
import QrCode
import AvatarNode
import ShareController

private func closeButtonImage(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: 0x808084, alpha: 0.1).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(theme.actionSheet.inputClearButtonColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private struct ThemeSettingsThemeEntry: Comparable, Identifiable {
    let index: Int
    let emoticon: String?
    let emojiFile: TelegramMediaFile?
    let themeReference: PresentationThemeReference?
    let nightMode: Bool
    var selected: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper?
    
    var stableId: Int {
        return index
    }
    
    static func ==(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.emoticon != rhs.emoticon {
            return false
        }
        
        if lhs.themeReference?.index != rhs.themeReference?.index {
            return false
        }
        if lhs.nightMode != rhs.nightMode {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        return true
    }
    
    static func <(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, action: @escaping (String?) -> Void) -> ListViewItem {
        return ThemeSettingsThemeIconItem(context: context, emoticon: self.emoticon, emojiFile: self.emojiFile, themeReference: self.themeReference, nightMode: self.nightMode, selected: self.selected, theme: self.theme, strings: self.strings, wallpaper: self.wallpaper, action: action)
    }
}


private class ThemeSettingsThemeIconItem: ListViewItem {
    let context: AccountContext
    let emoticon: String?
    let emojiFile: TelegramMediaFile?
    let themeReference: PresentationThemeReference?
    let nightMode: Bool
    let selected: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper?
    let action: (String?) -> Void
    
    public init(context: AccountContext, emoticon: String?, emojiFile: TelegramMediaFile?, themeReference: PresentationThemeReference?, nightMode: Bool, selected: Bool, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper?, action: @escaping (String?) -> Void) {
        self.context = context
        self.emoticon = emoticon
        self.emojiFile = emojiFile
        self.themeReference = themeReference
        self.nightMode = nightMode
        self.selected = selected
        self.theme = theme
        self.strings = strings
        self.wallpaper = wallpaper
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsThemeItemIconNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ThemeSettingsThemeItemIconNode)
            if let nodeValue = node() as? ThemeSettingsThemeItemIconNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.emoticon)
    }
}

private struct ThemeSettingsThemeItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
    let entries: [ThemeSettingsThemeEntry]
}

private func ensureThemeVisible(listNode: ListView, emoticon: String?, animated: Bool) -> Bool {
    var resultNode: ThemeSettingsThemeItemIconNode?
    var previousNode: ThemeSettingsThemeItemIconNode?
    var nextNode: ThemeSettingsThemeItemIconNode?
    listNode.forEachItemNode { node in
        guard let node = node as? ThemeSettingsThemeItemIconNode else {
            return
        }
        if resultNode == nil {
            if node.item?.emoticon == emoticon {
                resultNode = node
            } else {
                previousNode = node
            }
        } else if nextNode == nil {
            nextNode = node
        }
    }
    if let resultNode = resultNode {
        var nodeToEnsure = resultNode
        if case let .visible(resultVisibility) = resultNode.visibility, resultVisibility == 1.0 {
            if let previousNode = previousNode, case let .visible(previousVisibility) = previousNode.visibility, previousVisibility < 0.5 {
                nodeToEnsure = previousNode
            } else if let nextNode = nextNode, case let .visible(nextVisibility) = nextNode.visibility, nextVisibility < 0.5 {
                nodeToEnsure = nextNode
            }
        }
        listNode.ensureItemNodeVisible(nodeToEnsure, animated: animated, overflow: 57.0)
        return true
    } else {
        return false
    }
}

private func preparedTransition(context: AccountContext, action: @escaping (String?) -> Void, from fromEntries: [ThemeSettingsThemeEntry], to toEntries: [ThemeSettingsThemeEntry], crossfade: Bool) -> ThemeSettingsThemeItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action), directionHint: nil) }
    
    return ThemeSettingsThemeItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade, entries: toEntries)
}

private var cachedBorderImages: [String: UIImage] = [:]
private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = cachedBorderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)

            let lineWidth: CGFloat
            if selected {
                lineWidth = 2.0
                context.setLineWidth(lineWidth)
                context.setStrokeColor(theme.list.itemBlocksBackgroundColor.cgColor)
                
                context.strokeEllipse(in: bounds.insetBy(dx: 3.0 + lineWidth / 2.0, dy: 3.0 + lineWidth / 2.0))
                
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0x999999)
                }
                context.setStrokeColor(accentColor.cgColor)
            } else {
                context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
                lineWidth = 1.0
            }

            if bordered || selected {
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: 1.0 + lineWidth / 2.0, dy: 1.0 + lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 9, topCapHeight: 9)
        cachedBorderImages[key] = image
        return image
    }
}

private final class ThemeSettingsThemeItemIconNode : ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let emojiContainerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let textNode: TextNode
    private let emojiNode: TextNode
    private let emojiImageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    var snapshotView: UIView?
    
    var item: ThemeSettingsThemeIconItem?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.visibilityStatus = self.visibility != .none
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.animatedStickerNode?.visibility = self.visibilityStatus
            }
        }
    }
    
    private let stickerFetchedDisposable = MetaDisposable()

    init() {
        self.containerNode = ASDisplayNode()
        self.emojiContainerNode = ASDisplayNode()

        self.imageNode = TransformImageNode()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 82.0, height: 108.0))
        self.imageNode.isLayerBacked = true
        self.imageNode.cornerRadius = 8.0
        self.imageNode.clipsToBounds = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 84.0, height: 110.0))
        self.overlayNode.isLayerBacked = true

        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.emojiNode = TextNode()
        self.emojiNode.isUserInteractionEnabled = false
        self.emojiNode.displaysAsynchronously = false
        
        self.emojiImageNode = TransformImageNode()
        
        self.placeholderNode = StickerShimmerEffectNode()

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.overlayNode)
        self.containerNode.addSubnode(self.textNode)
        
        self.addSubnode(self.emojiContainerNode)
        self.emojiContainerNode.addSubnode(self.emojiNode)
        self.emojiContainerNode.addSubnode(self.emojiImageNode)
        self.emojiContainerNode.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.emojiImageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    strongSelf.emojiImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            firstTime = false
        }
    }

    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        let emojiFrame = CGRect(origin: CGPoint(x: 28.0, y: 71.0), size: CGSize(width: 34.0, height: 34.0))
        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + emojiFrame.minX, y: rect.minY + emojiFrame.minY), size: emojiFrame.size), within: containerSize)
    }
    
    override func selected() {
        let wasSelected = self.item?.selected ?? false
        super.selected()
        
        if let animatedStickerNode = self.animatedStickerNode {
            Queue.mainQueue().after(0.1) {
                if !wasSelected {
                    animatedStickerNode.seekTo(.frameIndex(0))
                    animatedStickerNode.play()
                    
                    let scale: CGFloat = 1.95
                    animatedStickerNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
                    animatedStickerNode.layer.animateSpring(from: 1.0 as NSNumber, to: scale as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    
                    animatedStickerNode.completed = { [weak animatedStickerNode, weak self] _ in
                        guard let item = self?.item, item.selected else {
                            return
                        }
                        animatedStickerNode?.transform = CATransform3DIdentity
                        animatedStickerNode?.layer.animateSpring(from: scale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    }
                }
            }
        }
        
    }
    
    func asyncLayout() -> (ThemeSettingsThemeIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeEmojiLayout = TextNode.asyncLayout(self.emojiNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedEmoticon = false
            var updatedThemeReference = false
            var updatedTheme = false
            var updatedWallpaper = false
            var updatedSelected = false
            var updatedNightMode = false
            
            if currentItem?.emoticon != item.emoticon {
                updatedEmoticon = true
            }
            if currentItem?.themeReference != item.themeReference {
                updatedThemeReference = true
            }
            if currentItem?.wallpaper != item.wallpaper {
                updatedWallpaper = true
            }
            if currentItem?.theme !== item.theme {
                updatedTheme = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            if currentItem?.nightMode != item.nightMode {
                updatedNightMode = true
            }
            
            let text = NSAttributedString(string: item.strings.Conversation_Theme_NoTheme, font: Font.semibold(15.0), textColor: item.theme.actionSheet.controlAccentColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let emoticon = item.emoticon
            let title = NSAttributedString(string: emoticon != nil ? "" : "❌", font: Font.regular(22.0), textColor: .black)
            let (_, emojiApply) = makeEmojiLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 120.0, height: 90.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                        
                    if updatedThemeReference || updatedWallpaper || updatedNightMode {
                        if let themeReference = item.themeReference {
                            strongSelf.imageNode.setSignal(themeIconImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, theme: themeReference, color: nil, wallpaper: item.wallpaper, nightMode: item.nightMode, emoticon: true, qr: true))
                            strongSelf.imageNode.backgroundColor = nil
                        }
                    }
                    if item.themeReference == nil {
                        strongSelf.imageNode.backgroundColor = item.theme.actionSheet.opaqueItemBackgroundColor
                    }
                    
                    if updatedTheme || updatedSelected {
                        strongSelf.overlayNode.image = generateBorderImage(theme: item.theme, bordered: false, selected: item.selected)
                    }
                    
                    if !item.selected && currentItem?.selected == true, let animatedStickerNode = strongSelf.animatedStickerNode {
                        animatedStickerNode.transform = CATransform3DIdentity
                        
                        let initialScale: CGFloat = CGFloat((animatedStickerNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
                        animatedStickerNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((90.0 - textLayout.size.width) / 2.0), y: 24.0), size: textLayout.size)
                    strongSelf.textNode.isHidden = item.emoticon != nil
                    
                    strongSelf.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    strongSelf.emojiContainerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    strongSelf.emojiContainerNode.frame = CGRect(origin: CGPoint(x: 15.0, y: -15.0), size: CGSize(width: 90.0, height: 120.0))
                    
                    let _ = textApply()
                    let _ = emojiApply()

                    let imageSize = CGSize(width: 82.0, height: 108.0)
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 4.0, y: 6.0), size: imageSize)
                    let applyLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
                    applyLayout()
                    
                    strongSelf.overlayNode.frame = strongSelf.imageNode.frame.insetBy(dx: -1.0, dy: -1.0)
                    strongSelf.emojiNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 79.0), size: CGSize(width: 90.0, height: 30.0))
                    
                    let emojiFrame = CGRect(origin: CGPoint(x: 28.0, y: 71.0), size: CGSize(width: 34.0, height: 34.0))
                    if let file = item.emojiFile, updatedEmoticon {
                        let imageApply = strongSelf.emojiImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: emojiFrame.size, boundingSize: emojiFrame.size, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        strongSelf.emojiImageNode.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, resource: file.resource, animated: true, nilIfEmpty: true))
                        strongSelf.emojiImageNode.frame = emojiFrame
                        
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = strongSelf.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = AnimatedStickerNode()
                            animatedStickerNode.started = { [weak self] in
                                self?.emojiImageNode.isHidden = true
                            }
                            strongSelf.animatedStickerNode = animatedStickerNode
                            strongSelf.emojiContainerNode.insertSubnode(animatedStickerNode, belowSubnode: strongSelf.placeholderNode)
                            let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource), width: 128, height: 128, playbackMode: .still(.start), mode: .direct(cachePathPrefix: pathPrefix))
                            
                            animatedStickerNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                        }
                        animatedStickerNode.autoplay = true
                        animatedStickerNode.visibility = strongSelf.visibilityStatus
                        
                        strongSelf.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)).start())
                        
                        let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
                        strongSelf.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: file.immediateThumbnailData, size: emojiFrame.size, imageSize: thumbnailDimensions.cgSize)
                        strongSelf.placeholderNode.frame = emojiFrame
                    }
                    
                    if let animatedStickerNode = strongSelf.animatedStickerNode {
                        animatedStickerNode.frame = emojiFrame
                        animatedStickerNode.updateLayout(size: emojiFrame.size)
                    }
                }
            })
        }
    }
    
    func crossfade() {
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            snapshotView.transform = self.containerNode.view.transform
            snapshotView.frame = self.containerNode.view.frame
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatQrCodeScreen.themeCrossfadeDuration, delay: ChatQrCodeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
    }
        
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

final class ChatQrCodeScreen: ViewController {
    static let themeCrossfadeDuration: Double = 0.3
    static let themeCrossfadeDelay: Double = 0.05
    
    private var controllerNode: ChatQrCodeScreenNode {
        return self.displayNode as! ChatQrCodeScreenNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peer: Peer
    
    private var presentationData: PresentationData
    private var presentationThemePromise = Promise<PresentationTheme?>()
    private var presentationDataDisposable: Disposable?
    
    var dismissed: (() -> Void)?
    
    init(context: AccountContext, peer: Peer) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
                
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationThemePromise.set(.single(nil))
        
        self.presentationDataDisposable = (combineLatest(context.sharedContext.presentationData, self.presentationThemePromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, theme in
            if let strongSelf = self {
                var presentationData = presentationData
                if let theme = theme {
                    presentationData = presentationData.withUpdated(theme: theme)
                }
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.ready.set(self.controllerNode.ready.get())
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatQrCodeScreenNode(context: self.context, presentationData: self.presentationData, controller: self, peer: self.peer)
        self.controllerNode.previewTheme = { [weak self] _, _, theme in
            self?.presentationThemePromise.set(.single(theme))
        }
        self.controllerNode.present = { [weak self] c in
            self?.present(c, in: .current)
        }
        self.controllerNode.completion = { [weak self] emoticon in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        }
    }
    
    override public func loadView() {
        super.loadView()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
    
        self.controllerNode.animateOut(completion: completion)
        
        self.dismissed?()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private func iconColors(theme: PresentationTheme) -> [String: UIColor] {
    let accentColor = theme.actionSheet.controlAccentColor
    var colors: [String: UIColor] = [:]
    colors["Sunny.Path 14.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 15.Path.Stroke 1"] = accentColor
    colors["Path.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 39.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 24.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 25.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 18.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 41.Path.Stroke 1"] = accentColor
    colors["Sunny.Path 43.Path.Stroke 1"] = accentColor
    colors["Path 10.Path.Fill 1"] = accentColor
    colors["Path 11.Path.Fill 1"] = accentColor
    return colors
}

private let defaultEmoticon = "🏠"

private class ChatQrCodeScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var controller: ChatQrCodeScreen?
    
    private let contentNode: QrContentNode
    
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let topContentContainerNode: SparseNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let cancelButton: HighlightableButtonNode
    private let switchThemeButton: HighlightTrackingButtonNode
    private let animationContainerNode: ASDisplayNode
    private var animationNode: AnimationNode
    private let doneButton: SolidRoundedButtonNode
    
    private let listNode: ListView
    private var entries: [ThemeSettingsThemeEntry]?
    private var enqueuedTransitions: [ThemeSettingsThemeItemNodeTransition] = []
    private var initialized = false
    private var themes: [TelegramTheme] = []
    
    let ready = Promise<Bool>()
    
    private let peer: Peer
    
    private var initiallySelectedEmoticon: String?
    private var selectedEmoticon: String? = nil {
        didSet {
            self.selectedEmoticonPromise.set(self.selectedEmoticon)
        }
    }
    private var selectedEmoticonPromise = ValuePromise<String?>(nil)

    private var isDarkAppearancePromise: ValuePromise<Bool>
    private var isDarkAppearance: Bool = false {
        didSet {
            self.isDarkAppearancePromise.set(self.isDarkAppearance)
        }
    }
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let disposable = MetaDisposable()
    
    var present: ((ViewController) -> Void)?
    var previewTheme: ((String?, Bool?, PresentationTheme) -> Void)?
    var completion: ((String?) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData, controller: ChatQrCodeScreen, peer: Peer) {
        self.context = context
        self.controller = controller
        self.peer = peer
        self.presentationData = presentationData
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
                
        self.contentNode = QrContentNode(context: context, peer: peer, isStatic: false)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        
        self.topContentContainerNode = SparseNode()
        self.topContentContainerNode.isOpaque = false

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
        
        self.isDarkAppearance = self.presentationData.theme.overallDarkAppearance
        self.isDarkAppearancePromise = ValuePromise(self.presentationData.theme.overallDarkAppearance)
        
        let backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        let textColor = self.presentationData.theme.actionSheet.primaryTextColor
        let blurStyle: UIBlurEffect.Style = self.presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.PeerInfo_QRCode_Title, font: Font.semibold(16.0), textColor: textColor)
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
        
        self.switchThemeButton = HighlightTrackingButtonNode()
        self.animationContainerNode = ASDisplayNode()
        self.animationContainerNode.isUserInteractionEnabled = false
        
        self.animationNode = AnimationNode(animation: self.isDarkAppearance ? "anim_sun_reverse" : "anim_sun", colors: iconColors(theme: self.presentationData.theme), scale: 1.0)
        self.animationNode.isUserInteractionEnabled = false
        
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.InviteLink_QRCode_Share
        
        self.listNode = ListView()
        self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false

        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.contentNode)
        
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.wrappingScrollNode.addSubnode(self.topContentContainerNode)
        
        self.backgroundNode.addSubnode(self.effectNode)
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.doneButton)
        
        self.topContentContainerNode.addSubnode(self.animationContainerNode)
        self.animationContainerNode.addSubnode(self.animationNode)
        self.topContentContainerNode.addSubnode(self.switchThemeButton)
        self.topContentContainerNode.addSubnode(self.listNode)
        self.topContentContainerNode.addSubnode(self.cancelButton)
        
        self.switchThemeButton.addTarget(self, action: #selector(self.switchThemePressed), forControlEvents: .touchUpInside)
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.doneButton.isUserInteractionEnabled = false
                
                strongSelf.contentNode.generateImage { [weak self] image in
                    if let strongSelf = self, let image = image, let jpgData = image.jpegData(compressionQuality: 0.9) {
                        let tempFilePath = NSTemporaryDirectory() + "t_me-\(peer.addressName ?? "").jpg"
                        try? FileManager.default.removeItem(atPath: tempFilePath)
                        let tempFileUrl = URL(fileURLWithPath: tempFilePath)
                        try? jpgData.write(to: tempFileUrl)
                        
                        let activityController = UIActivityViewController(activityItems: [tempFileUrl], applicationActivities: [ShareToInstagramActivity(context: strongSelf.context)])
                        activityController.completionWithItemsHandler = { [weak self] _, finished, _, _ in
                            if let strongSelf = self {
                                if finished {
                                    strongSelf.completion?(strongSelf.selectedEmoticon)
                                } else {
                                    strongSelf.doneButton.isUserInteractionEnabled = true
                                }
                            }
                        }
                        if let window = strongSelf.view.window {
                            activityController.popoverPresentationController?.sourceView = window
                            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                        }
                        context.sharedContext.applicationBindings.presentNativeController(activityController)
                    }
                }
            }
        }
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let initiallySelectedEmoticon: Signal<String, NoError>
        let sharedData = self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
        |> take(1)
        if self.peer.id == self.context.account.peerId {
            initiallySelectedEmoticon = sharedData
            |> map { sharedData -> String in
                let themeSettings: PresentationThemeSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) {
                    themeSettings = current
                } else {
                    themeSettings = PresentationThemeSettings.defaultSettings
                }
                return themeSettings.theme.emoticon ?? defaultEmoticon
            }
        } else {
            let cachedData = self.context.account.postbox.transaction { transaction in
                return transaction.getPeerCachedData(peerId: peer.id)
            }
            initiallySelectedEmoticon = combineLatest(cachedData, sharedData)
            |> map { cachedData, sharedData -> String in
                let themeSettings: PresentationThemeSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) {
                    themeSettings = current
                } else {
                    themeSettings = PresentationThemeSettings.defaultSettings
                }
                let currentDefaultEmoticon = themeSettings.theme.emoticon ?? defaultEmoticon
                
                if let cachedData = cachedData as? CachedUserData {
                    return cachedData.themeEmoticon ?? currentDefaultEmoticon
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.themeEmoticon ?? currentDefaultEmoticon
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.themeEmoticon ?? currentDefaultEmoticon
                } else {
                    return currentDefaultEmoticon
                }
            }
        }
        
        self.disposable.set(combineLatest(queue: Queue.mainQueue(), animatedEmojiStickers, initiallySelectedEmoticon, self.context.engine.themes.getChatThemes(accountManager: self.context.sharedContext.accountManager), self.selectedEmoticonPromise.get(), self.isDarkAppearancePromise.get()).start(next: { [weak self] animatedEmojiStickers, initiallySelectedEmoticon, themes, selectedEmoticon, isDarkAppearance in
            guard let strongSelf = self else {
                return
            }
            
            var selectedEmoticon = selectedEmoticon
            if strongSelf.initiallySelectedEmoticon == nil {
                strongSelf.initiallySelectedEmoticon = initiallySelectedEmoticon
                strongSelf.selectedEmoticon = initiallySelectedEmoticon
                selectedEmoticon = initiallySelectedEmoticon
            }
            
            let isFirstTime = strongSelf.entries == nil
            let presentationData = strongSelf.presentationData
                
            var entries: [ThemeSettingsThemeEntry] = []
            
            let defaultWallpaper: TelegramWallpaper?
            if isDarkAppearance {
                let dayTheme = makeDefaultPresentationTheme(reference: .dayClassic, serviceBackgroundColor: nil)
                defaultWallpaper = dayTheme.chat.defaultWallpaper.withUpdatedSettings(WallpaperSettings(blur: false, motion: false, colors: [0x00b3dd, 0x3b59f2, 0x358be2, 0xa434cf], intensity: -55, rotation: nil))
            } else {
                defaultWallpaper = nil
            }
            entries.append(ThemeSettingsThemeEntry(index: 0, emoticon: defaultEmoticon, emojiFile: animatedEmojiStickers[defaultEmoticon]?.first?.file, themeReference: .builtin(isDarkAppearance ? .night : .dayClassic), nightMode: isDarkAppearance, selected: selectedEmoticon == defaultEmoticon, theme: presentationData.theme, strings: presentationData.strings, wallpaper: defaultWallpaper))
            for theme in themes {
                guard let emoticon = theme.emoticon else {
                    continue
                }
                entries.append(ThemeSettingsThemeEntry(index: entries.count, emoticon: emoticon, emojiFile: animatedEmojiStickers[emoticon]?.first?.file, themeReference: .cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: nil)), nightMode: isDarkAppearance, selected: selectedEmoticon == theme.emoticon, theme: presentationData.theme, strings: presentationData.strings, wallpaper: nil))
            }
            
            let wallpaper: TelegramWallpaper
            if selectedEmoticon == defaultEmoticon {
                let presentationTheme = makeDefaultPresentationTheme(reference: isDarkAppearance ? .night : .dayClassic, serviceBackgroundColor: nil)
                if isDarkAppearance {
                    wallpaper = entries.first?.wallpaper ?? .color(0x000000)
                } else {
                    wallpaper = presentationTheme.chat.defaultWallpaper
                }
            } else if let theme = themes.first(where: { $0.emoticon == selectedEmoticon }), let presentationTheme = makePresentationTheme(cloudTheme: theme, dark: isDarkAppearance) {
                wallpaper = presentationTheme.chat.defaultWallpaper
            } else {
                wallpaper = .color(0x000000)
            }
            
            let action: (String?) -> Void = { [weak self] emoticon in
                if let strongSelf = self, strongSelf.selectedEmoticon != emoticon {
                    strongSelf.animateCrossfade(animateIcon: true)
                    
                    var presentationTheme: PresentationTheme?
                    if emoticon == defaultEmoticon {
                        presentationTheme = makeDefaultPresentationTheme(reference: isDarkAppearance ? .night : .dayClassic, serviceBackgroundColor: nil)
                    } else if let theme = themes.first(where: { $0.emoticon == emoticon }) {
                        if let theme = makePresentationTheme(cloudTheme: theme, dark: isDarkAppearance) {
                            presentationTheme = theme
                        }
                    }
                    if let presentationTheme = presentationTheme {
                        strongSelf.previewTheme?(emoticon, strongSelf.isDarkAppearance, presentationTheme)
                    }
                    strongSelf.selectedEmoticon = emoticon
                    let _ = ensureThemeVisible(listNode: strongSelf.listNode, emoticon: emoticon, animated: true)
                }
            }
            let previousEntries = strongSelf.entries ?? []
            let crossfade = previousEntries.count != entries.count
            let transition = preparedTransition(context: strongSelf.context, action: action, from: previousEntries, to: entries, crossfade: crossfade)
            strongSelf.enqueueTransition(transition)
            
            strongSelf.entries = entries
            strongSelf.themes = themes
            
            strongSelf.contentNode.update(wallpaper: wallpaper, isDarkAppearance: isDarkAppearance, selectedEmoticon: selectedEmoticon)
            
            if isFirstTime {
                for theme in themes {
                    if let wallpaper = theme.settings?.first?.wallpaper, case let .file(file) = wallpaper {
                        let account = strongSelf.context.account
                        let accountManager = strongSelf.context.sharedContext.accountManager
                        let path = accountManager.mediaBox.cachedRepresentationCompletePath(file.file.resource.id, representation: CachedPreparedPatternWallpaperRepresentation())
                        if !FileManager.default.fileExists(atPath: path) {
                            let accountFullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                                let accountResource = account.postbox.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPreparedPatternWallpaperRepresentation(), complete: false, fetch: true)
                                
                                let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .media(media: .standalone(media: file.file), resource: file.file.resource))
                                let fetchedFullSizeDisposable = fetchedFullSize.start()
                                let fullSizeDisposable = accountResource.start(next: { next in
                                    subscriber.putNext((next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                                    
                                    if next.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedRead) {
                                        accountManager.mediaBox.storeCachedResourceRepresentation(file.file.resource, representation: CachedPreparedPatternWallpaperRepresentation(), data: data)
                                    }
                                }, error: subscriber.putError, completed: subscriber.putCompletion)
                                
                                return ActionDisposable {
                                    fetchedFullSizeDisposable.dispose()
                                    fullSizeDisposable.dispose()
                                }
                            }
                            let _ = accountFullSizeData.start()
                        }
                    }
                }
            }
        }))
        
        self.switchThemeButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.animationNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.animationNode.alpha = 0.4
                } else {
                    strongSelf.animationNode.alpha = 1.0
                    strongSelf.animationNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.ready.set(self.contentNode.isReady)
    }
    
    private func enqueueTransition(_ transition: ThemeSettingsThemeItemNodeTransition) {
        self.enqueuedTransitions.append(transition)
        
        while !self.enqueuedTransitions.isEmpty {
            self.dequeueTransition()
        }
    }
    
    private func dequeueTransition() {
        guard let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if self.initialized && transition.crossfade {
            options.insert(.AnimateCrossfade)
        }
        options.insert(.Synchronous)
        
        var scrollToItem: ListViewScrollToItem?
        if !self.initialized {
            if let index = transition.entries.firstIndex(where: { entry in
                return entry.emoticon == self.initiallySelectedEmoticon
            }) {
                scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-57.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                self.initialized = true
            }
            self.initialized = true
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard !self.animatedOut else {
            return
        }
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
                        
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.semibold(16.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        
        if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
        self.doneButton.updateTheme(SolidRoundedButtonTheme(theme: self.presentationData.theme))
        
        if self.animationNode.isPlaying {
            if let animationNode = self.animationNode.makeCopy(colors: iconColors(theme: self.presentationData.theme), progress: 0.2) {
                let previousAnimationNode = self.animationNode
                self.animationNode = animationNode
                
                animationNode.completion = { [weak previousAnimationNode] in
                    previousAnimationNode?.removeFromSupernode()
                }
                animationNode.isUserInteractionEnabled = false
                animationNode.frame = previousAnimationNode.frame
                previousAnimationNode.supernode?.insertSubnode(animationNode, belowSubnode: previousAnimationNode)
                previousAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatQrCodeScreen.themeCrossfadeDuration, removeOnCompletion: false)
                animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else {
            self.animationNode.setAnimation(name: self.isDarkAppearance ? "anim_sun_reverse" : "anim_sun", colors: iconColors(theme: self.presentationData.theme))
        }
    }
        
    override func didLoad() {
        super.didLoad()
        
        self.wrappingScrollNode.view.delegate = self
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.listNode.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }

    @objc func switchThemePressed() {
        self.switchThemeButton.isUserInteractionEnabled = false
        Queue.mainQueue().after(0.5) {
            self.switchThemeButton.isUserInteractionEnabled = true
        }
        
        self.animateCrossfade(animateIcon: false)
        self.animationNode.setAnimation(name: self.isDarkAppearance ? "anim_sun_reverse" : "anim_sun", colors: iconColors(theme: self.presentationData.theme))
        self.animationNode.playOnce()
        
        let isDarkAppearance = !self.isDarkAppearance
        
        var presentationTheme: PresentationTheme?
        if self.selectedEmoticon == defaultEmoticon {
            presentationTheme = makeDefaultPresentationTheme(reference: isDarkAppearance ? .night : .dayClassic, serviceBackgroundColor: nil)
        } else if let theme = self.themes.first(where: { $0.emoticon == self.selectedEmoticon }) {
            if let theme = makePresentationTheme(cloudTheme: theme, dark: isDarkAppearance) {
                presentationTheme = theme
            }
        }
        if let presentationTheme = presentationTheme {
            self.previewTheme?(self.selectedEmoticon, isDarkAppearance, presentationTheme)
        }
        
        self.isDarkAppearance = isDarkAppearance
        
        if isDarkAppearance {
            let _ = ApplicationSpecificNotice.incrementChatSpecificThemeDarkPreviewTip(accountManager: self.context.sharedContext.accountManager, count: 3, timestamp: Int32(Date().timeIntervalSince1970)).start()
        } else {
            let _ = ApplicationSpecificNotice.incrementChatSpecificThemeLightPreviewTip(accountManager: self.context.sharedContext.accountManager, count: 3, timestamp: Int32(Date().timeIntervalSince1970)).start()
        }
    }
    
    private func animateCrossfade(animateIcon: Bool) {
        if let snapshotView = self.contentNode.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.contentNode.view.insertSubview(snapshotView, aboveSubview: self.contentNode.containerNode.view)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatQrCodeScreen.themeCrossfadeDuration, delay: ChatQrCodeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
        
        if animateIcon, let snapshotView = self.animationNode.view.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = self.animationNode.frame
            self.animationNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.animationNode.view)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatQrCodeScreen.themeCrossfadeDuration, delay: ChatQrCodeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
        
        Queue.mainQueue().after(ChatQrCodeScreen.themeCrossfadeDelay) {
            if let effectView = self.effectNode.view as? UIVisualEffectView {
                UIView.animate(withDuration: ChatQrCodeScreen.themeCrossfadeDuration, delay: 0.0, options: .curveLinear) {
                    effectView.effect = UIBlurEffect(style: self.presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark)
                } completion: { _ in
                }
            }

            let previousColor = self.contentBackgroundNode.backgroundColor ?? .clear
            self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
            self.contentBackgroundNode.layer.animate(from: previousColor.cgColor, to: (self.contentBackgroundNode.backgroundColor ?? .clear).cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: ChatQrCodeScreen.themeCrossfadeDuration)
        }
                
        if let snapshotView = self.contentContainerNode.view.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = self.contentContainerNode.frame
            self.contentContainerNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.contentContainerNode.view)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatQrCodeScreen.themeCrossfadeDuration, delay: ChatQrCodeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
                
        self.listNode.forEachVisibleItemNode { node in
            if let node = node as? ThemeSettingsThemeItemIconNode {
                node.crossfade()
            }
        }
    }
    
    private var animatedOut = false
    func animateIn() {
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        transition.animateView({
            self.bounds = targetBounds
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.animatedOut = true
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        self.wrappingScrollNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
                completion?()
            }
        })
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        let contentHeight = titleHeight + bottomInset + 188.0
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width - 90.0, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 19.0 + UIScreenPixel), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
                
        let switchThemeSize = CGSize(width: 44.0, height: 44.0)
        let switchThemeFrame = CGRect(origin: CGPoint(x: 3.0, y: 6.0), size: switchThemeSize)
        transition.updateFrame(node: self.switchThemeButton, frame: switchThemeFrame)
        transition.updateFrame(node: self.animationContainerNode, frame: switchThemeFrame.insetBy(dx: 9.0, dy: 9.0))
        transition.updateFrame(node: self.animationNode, frame: CGRect(origin: CGPoint(), size: self.animationContainerNode.frame.size))
        
        let cancelSize = CGSize(width: 44.0, height: 44.0)
        let cancelFrame = CGRect(origin: CGPoint(x: contentFrame.width - cancelSize.width - 3.0, y: 6.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 6.0, width: contentFrame.width, height: doneButtonHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        transition.updateFrame(node: self.topContentContainerNode, frame: contentContainerFrame)
        
        var listInsets = UIEdgeInsets()
        listInsets.top += layout.safeInsets.left + 12.0
        listInsets.bottom += layout.safeInsets.right + 12.0
        
        let contentSize = CGSize(width: contentFrame.width, height: 120.0)
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: contentSize.height, height: contentSize.width)
        self.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0 + titleHeight + 6.0)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.contentNode.updateLayout(size: layout.size, topInset: 44.0, bottomInset: contentHeight, transition: transition)
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
    }
}

private class QrContentNode: ASDisplayNode {
    private let context: AccountContext
    private let peer: Peer
    private let isStatic: Bool
    
    fileprivate let containerNode: ASDisplayNode
    fileprivate let wallpaperBackgroundNode: WallpaperBackgroundNode
    private let codeBackgroundNode: ASDisplayNode
    private let codeForegroundNode: ASDisplayNode
    private var codeForegroundContentNode: ASDisplayNode?
    private var codeForegroundDimNode: ASDisplayNode
    private let codeMaskNode: ASDisplayNode
    private let codeTextNode: ImmediateTextNode
    private let codeImageNode: TransformImageNode
    private let codeIconBackgroundNode: ASImageNode
    private let codeStaticIconNode: ASImageNode?
    private let codeAnimatedIconNode: AnimatedStickerNode?
    private let avatarNode: ImageNode
    private var qrCodeSize: Int?
        
    private var currentParams: (TelegramWallpaper, Bool, String?)?
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private let _ready = Promise<Bool>()
    var isReady: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    init(context: AccountContext, peer: Peer, isStatic: Bool = false) {
        self.context = context
        self.peer = peer
        self.isStatic = isStatic
        
        self.containerNode = ASDisplayNode()
        
        self.wallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: false, useExperimentalImplementation: context.sharedContext.immediateExperimentalUISettings.experimentalBackground)
        
        self.codeBackgroundNode = ASDisplayNode()
        self.codeBackgroundNode.backgroundColor = .white
        self.codeBackgroundNode.cornerRadius = 42.0
        if #available(iOS 13.0, *) {
            self.codeBackgroundNode.layer.cornerCurve = .continuous
        }
        
        self.codeForegroundNode = ASDisplayNode()
        self.codeForegroundNode.backgroundColor = .black
        
        self.codeForegroundDimNode = ASDisplayNode()
        self.codeForegroundDimNode.alpha = 0.3
        self.codeForegroundDimNode.backgroundColor = .black
        
        self.codeMaskNode = ASDisplayNode()
        
        self.codeImageNode = TransformImageNode()
        self.codeIconBackgroundNode = ASImageNode()
        
        if isStatic {
            let codeStaticIconNode = ASImageNode()
            codeStaticIconNode.displaysAsynchronously = false
            codeStaticIconNode.contentMode = .scaleToFill
            codeStaticIconNode.image = UIImage(bundleImageName: "Share/QrPlaneIcon")
            self.codeStaticIconNode = codeStaticIconNode
            self.codeAnimatedIconNode = nil
        } else {
            let codeAnimatedIconNode = AnimatedStickerNode()
            codeAnimatedIconNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "PlaneLogoPlain"), width: 120, height: 120, mode: .direct(cachePathPrefix: nil))
            codeAnimatedIconNode.visibility = true
            self.codeAnimatedIconNode = codeAnimatedIconNode
            self.codeStaticIconNode = nil
        }
        
        self.codeTextNode = ImmediateTextNode()
        self.codeTextNode.displaysAsynchronously = false
        self.codeTextNode.attributedText = NSAttributedString(string: "@\(peer.addressName ?? "")".uppercased(), font: Font.with(size: 23.0, design: .round, weight: .bold, traits: []), textColor: .black)
        self.codeTextNode.truncationMode = .byCharWrapping
        self.codeTextNode.maximumNumberOfLines = 2
        self.codeTextNode.textAlignment = .center
        if isStatic {
            self.codeTextNode.setNeedsDisplayAtScale(3.0)
        }
        
        self.avatarNode = ImageNode()
        self.avatarNode.displaysAsynchronously = false
        self.avatarNode.setSignal(peerAvatarCompleteImage(account: context.account, peer: EnginePeer(peer), size: CGSize(width: 180.0, height: 180.0), font: avatarPlaceholderFont(size: 78.0), fullSize: true))
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.addSubnode(self.wallpaperBackgroundNode)
        
        self.containerNode.addSubnode(self.codeBackgroundNode)
        self.containerNode.addSubnode(self.codeForegroundNode)
        
        self.codeForegroundNode.addSubnode(self.codeForegroundDimNode)
        
        self.codeMaskNode.addSubnode(self.codeImageNode)
        self.codeMaskNode.addSubnode(self.codeIconBackgroundNode)
        self.codeMaskNode.addSubnode(self.codeTextNode)
        
        self.containerNode.addSubnode(self.avatarNode)
        
        if let codeStaticIconNode = self.codeStaticIconNode {
            self.containerNode.addSubnode(codeStaticIconNode)
        } else if let codeAnimatedIconNode = self.codeAnimatedIconNode {
            self.addSubnode(codeAnimatedIconNode)
        }
        
        let codeReadyPromise = ValuePromise<Bool>()
        self.codeImageNode.setSignal(qrCode(string: "https://t.me/\(peer.addressName ?? "")", color: .black, backgroundColor: nil, icon: .cutout, ecl: "Q") |> beforeNext { [weak self] size, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.qrCodeSize = size
            if let (size, topInset, bottomInset) = strongSelf.validLayout {
                strongSelf.updateLayout(size: size, topInset: topInset, bottomInset: bottomInset, transition: .immediate)
            }
            codeReadyPromise.set(true)
        } |> map { $0.1 }, attemptSynchronously: true)
        
        self._ready.set(combineLatest(codeReadyPromise.get(), self.wallpaperBackgroundNode.isReady)
        |> map { codeReady, wallpaperReady in
            return codeReady && wallpaperReady
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.codeForegroundNode.view.mask = self.codeMaskNode.view
    }
    
    func generateImage(completion: @escaping (UIImage?) -> Void) {
        guard let (wallpaper, isDarkAppearance, selectedEmoticon) = self.currentParams else {
            return
        }
        
        let size = CGSize(width: 390.0, height: 844.0)
        let scale: CGFloat = 3.0
        
        let copyNode = QrContentNode(context: self.context, peer: self.peer, isStatic: true)
        
        func prepare(view: UIView, scale: CGFloat) {
            view.contentScaleFactor = scale
            for subview in view.subviews {
                prepare(view: subview, scale: scale)
            }
        }
        prepare(view: copyNode.view, scale: scale)
        
        copyNode.updateLayout(size: size, topInset: 0.0, bottomInset: 0.0, transition: .immediate)
        copyNode.update(wallpaper: wallpaper, isDarkAppearance: isDarkAppearance, selectedEmoticon: selectedEmoticon)
        copyNode.frame = CGRect(x: -1000, y: -1000, width: size.width, height: size.height)
        
        self.addSubnode(copyNode)

        
        let _ = (copyNode.isReady
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak copyNode] _ in
            Queue.mainQueue().after(0.1) {
                if #available(iOS 10.0, *) {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = scale
                    let renderer = UIGraphicsImageRenderer(size: size, format: format)
                    let image = renderer.image { rendererContext in
                        copyNode?.containerNode.layer.render(in: rendererContext.cgContext)
                    }
                    completion(image)
                } else {
                    UIGraphicsBeginImageContextWithOptions(size, true, scale)
                    copyNode?.containerNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: size), afterScreenUpdates: true)
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    completion(image)
                }
                copyNode?.removeFromSupernode()
            }
        })
    }
        
    func update(wallpaper: TelegramWallpaper, isDarkAppearance: Bool, selectedEmoticon: String?) {
        self.currentParams = (wallpaper, isDarkAppearance, selectedEmoticon)
        
        self.wallpaperBackgroundNode.update(wallpaper: wallpaper)
        
        self.codeForegroundDimNode.alpha = isDarkAppearance ? 0.5 : 0.3
        
        if self.codeForegroundContentNode == nil, let contentNode = self.wallpaperBackgroundNode.makeDimmedNode() {
            contentNode.frame = CGRect(origin: CGPoint(x: -self.codeForegroundNode.frame.minX, y: -self.codeForegroundNode.frame.minY), size: self.wallpaperBackgroundNode.frame.size)
            self.codeForegroundContentNode = contentNode
            self.codeForegroundNode.insertSubnode(contentNode, at: 0)
        }
    }
    
    func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, topInset, bottomInset)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.updateFrame(node: self.wallpaperBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        self.wallpaperBackgroundNode.updateLayout(size: size, transition: transition)
        
        let textLength = self.codeTextNode.attributedText?.string.count ?? 0
        
        var topInset = topInset
        let avatarSize: CGSize
        let codeInset: CGFloat
        let imageSide: CGFloat
        let fontSize: CGFloat
        if size.width > 320.0 {
            avatarSize = CGSize(width: 100.0, height: 100.0)
            codeInset = 45.0
            imageSide = 220.0
            
            if size.width > 375.0 {
                if textLength > 12 {
                    fontSize = 22.0
                } else {
                    fontSize = 24.0
                }
            } else {
                if textLength > 12 {
                    fontSize = 21.0
                } else {
                    fontSize = 23.0
                }
            }
        } else {
            avatarSize = CGSize(width: 70.0, height: 70.0)
            codeInset = 55.0
            imageSide = 160.0
            topInset = floor(topInset * 0.6)
            if textLength > 12 {
                fontSize = 18.0
            } else {
                fontSize = 20.0
            }
        }
        
        self.codeTextNode.attributedText = NSAttributedString(string: self.codeTextNode.attributedText?.string ?? "", font: Font.with(size: fontSize, design: .round, weight: .bold, traits: []), textColor: .black)
        
        let codeBackgroundWidth = size.width - codeInset * 2.0
        let codeBackgroundHeight = floor(codeBackgroundWidth * 1.1)
        let codeBackgroundFrame = CGRect(x: codeInset, y: topInset + floor((size.height - bottomInset - codeBackgroundHeight) / 2.0), width: codeBackgroundWidth, height: codeBackgroundHeight)
        transition.updateFrame(node: self.codeBackgroundNode, frame: codeBackgroundFrame)
        transition.updateFrame(node: self.codeForegroundNode, frame: codeBackgroundFrame)
        transition.updateFrame(node: self.codeMaskNode, frame: CGRect(origin: CGPoint(), size: codeBackgroundFrame.size))
        transition.updateFrame(node: self.codeForegroundDimNode, frame: CGRect(origin: CGPoint(), size: codeBackgroundFrame.size))
        
        if let codeForegroundContentNode = self.codeForegroundContentNode {
            codeForegroundContentNode.frame = CGRect(origin: CGPoint(x: -self.codeForegroundNode.frame.minX, y: -self.codeForegroundNode.frame.minY), size: self.wallpaperBackgroundNode.frame.size)
        }
        
        let makeImageLayout = self.codeImageNode.asyncLayout()
        
        let imageSize = CGSize(width: imageSide, height: imageSide)
        let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil, scale: self.isStatic ? 3.0 : nil ))
        let _ = imageApply()
        
        let imageFrame = CGRect(origin: CGPoint(x: floor((codeBackgroundFrame.width - imageSize.width) / 2.0), y: floor((codeBackgroundFrame.width - imageSize.height) / 2.0)), size: imageSize)
        transition.updateFrame(node: self.codeImageNode, frame: imageFrame)

        let codeTextSize = self.codeTextNode.updateLayout(CGSize(width: codeBackgroundFrame.width - floor(imageFrame.minX * 1.5), height: codeBackgroundFrame.height))
        transition.updateFrame(node: self.codeTextNode, frame: CGRect(origin: CGPoint(x: floor((codeBackgroundFrame.width - codeTextSize.width) / 2.0), y: imageFrame.maxY + floor((codeBackgroundHeight - imageFrame.maxY - codeTextSize.height) / 2.0) - 5.0), size: codeTextSize))
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0), y: codeBackgroundFrame.minY - floor(avatarSize.height * 0.7)), size: avatarSize))
        
        if let qrCodeSize = self.qrCodeSize {
            let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
            let imageCenter = imageFrame.center.offsetBy(dx: codeBackgroundFrame.minX, dy: codeBackgroundFrame.minY)
            
            if let codeStaticIconNode = self.codeStaticIconNode {
                transition.updateBounds(node: codeStaticIconNode, bounds: CGRect(origin: CGPoint(), size: cutoutFrame.size))
                transition.updatePosition(node: codeStaticIconNode, position: imageCenter.offsetBy(dx: 0.0, dy: -1.0))
            } else if let codeAnimatedIconNode = self.codeAnimatedIconNode {
                codeAnimatedIconNode.updateLayout(size: cutoutFrame.size)
                
                transition.updateBounds(node: codeAnimatedIconNode, bounds: CGRect(origin: CGPoint(), size: cutoutFrame.size))
                transition.updatePosition(node: codeAnimatedIconNode, position: imageCenter.offsetBy(dx: 0.0, dy: -1.0))
            }
            
            let backgroundSize = CGSize(width: floorToScreenPixels(cutoutFrame.width - 8.0), height: floorToScreenPixels(cutoutFrame.height - 8.0))
            transition.updateFrame(node: self.codeIconBackgroundNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(imageFrame.center.x - backgroundSize.width / 2.0), y: floorToScreenPixels(imageFrame.center.y - backgroundSize.height / 2.0)), size: backgroundSize))
            if self.codeIconBackgroundNode.image == nil {
                self.codeIconBackgroundNode.image = generateFilledCircleImage(diameter: backgroundSize.width, color: .black)
            }
        }
    }
}