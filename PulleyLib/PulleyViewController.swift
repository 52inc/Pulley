//
//  PulleyViewController.swift
//  Pulley
//
//  Created by Brendan Lee on 7/6/16.
//  Copyright © 2016 52inc. All rights reserved.
//

import UIKit

/**
 *  The base delegate protocol for Pulley delegates.
 */
@objc public protocol PulleyDelegate: class {
    
    /** This is called after size changes, so if you care about the bottomSafeArea property for custom UI layout, you can use this value.
     * NOTE: It's not called *during* the transition between sizes (such as in an animation coordinator), but rather after the resize is complete.
     */
    @objc optional func drawerPositionDidChange(drawer: PulleyViewController, bottomSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for when Pulley goes to 'fullscreen'. Bottom safe area is provided for your convenience.
     */
    @objc optional func makeUIAdjustmentsForFullscreen(progress: CGFloat, bottomSafeArea: CGFloat)
    
    /**
     *  Make UI adjustments for changes in the drawer's distance-to-bottom. Bottom safe area is provided for your convenience.
     */
    @objc optional func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat)
}

/**
 *  View controllers in the drawer can implement this to receive changes in state or provide values for the different drawer positions.
 */
public protocol PulleyDrawerViewControllerDelegate: PulleyDelegate {
    
    /**
     *  Provide the collapsed drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: bottom safe area is provided for your convenience in computing a value to return.
     */
    func collapsedDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Provide the partialReveal drawer height for Pulley. Pulley does NOT automatically handle safe areas for you, however: bottom safe area is provided for your convenience in computing a value to return.
     */
    func partialRevealDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat
    
    /**
     *  Return the support drawer positions for your drawer.
     */
    func supportedDrawerPositions() -> [PulleyPosition]
}

/**
 *  View controllers that are the main content can implement this to receive changes in state.
 */
public protocol PulleyPrimaryContentControllerDelegate: PulleyDelegate {
    
    // Not currently used for anything, but it's here for parity with the hopes that it'll one day be used.
}

/**
 *  A completion block used for animation callbacks.
 */
public typealias PulleyAnimationCompletionBlock = ((_ finished: Bool) -> Void)

/**
 Represents a Pulley drawer position.
 
 - collapsed:         When the drawer is in its smallest form, at the bottom of the screen.
 - partiallyRevealed: When the drawer is partially revealed.
 - open:              When the drawer is fully open.
 - closed:            When the drawer is off-screen at the bottom of the view. Note: Users cannot close or reopen the drawer on their own. You must set this programatically
 */
public enum PulleyPosition: Int {
    
    case collapsed = 0
    case partiallyRevealed = 1
    case open = 2
    case closed = 3
    
    public static let all: [PulleyPosition] = [
        .collapsed,
        .partiallyRevealed,
        .open,
        .closed
    ]
    
    public static func positionFor(string: String?) -> PulleyPosition {
        
        guard let positionString = string?.lowercased() else {
            
            return .collapsed
        }
        
        switch positionString {
            
        case "collapsed":
            return .collapsed
            
        case "partiallyrevealed":
            return .partiallyRevealed
            
        case "open":
            return .open
            
        case "closed":
            return .closed
            
        default:
            print("PulleyViewController: Position for string '\(positionString)' not found. Available values are: collapsed, partiallyRevealed, open, and closed. Defaulting to collapsed.")
            return .collapsed
        }
    }
}

private let kPulleyDefaultCollapsedHeight: CGFloat = 68.0
private let kPulleyDefaultPartialRevealHeight: CGFloat = 264.0

open class PulleyViewController: UIViewController {
    
    // Interface Builder
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var primaryContentContainerView: UIView!
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet public var drawerContentContainerView: UIView!
    
    // Internal
    fileprivate let primaryContentContainer: UIView = UIView()
    fileprivate let drawerContentContainer: UIView = UIView()
    fileprivate let drawerShadowView: UIView = UIView()
    fileprivate let drawerScrollView: PulleyPassthroughScrollView = PulleyPassthroughScrollView()
    fileprivate let backgroundDimmingView: UIView = UIView()
    
    fileprivate var dimmingViewTapRecognizer: UITapGestureRecognizer?
    
    fileprivate var lastDragTargetContentOffset: CGPoint = CGPoint.zero

    // Public

    /// The current content view controller (shown behind the drawer).
    public fileprivate(set) var primaryContentViewController: UIViewController! {
        willSet {
            
            guard let controller = primaryContentViewController else {
                return
            }

            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = primaryContentViewController else {
                return
            }

            addChildViewController(controller)

            primaryContentContainer.addSubview(controller.view)
            
            controller.view.constrainToParent()
            
            controller.didMove(toParentViewController: self)

            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
    
    /// The current drawer view controller (shown in the drawer).
    public fileprivate(set) var drawerContentViewController: UIViewController! {
        willSet {

            guard let controller = drawerContentViewController else {
                return
            }

            controller.willMove(toParentViewController: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }

        didSet {

            guard let controller = drawerContentViewController else {
                return
            }

            addChildViewController(controller)

            drawerContentContainer.addSubview(controller.view)
            
            controller.view.constrainToParent()
            
            controller.didMove(toParentViewController: self)

            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
    
    /// Get the current bottom safe area for Pulley. This is a convenience accessor. Most delegate methods where you'd need it will deliver it as a parameter.
    public var bottomSafeSpace: CGFloat {
        get {
            return getBottomSafeArea()
        }
    }
    
    /// The content view controller and drawer controller can receive delegate events already. This lets another object observe the changes, if needed.
    public weak var delegate: PulleyDelegate?
    
    /// The current position of the drawer.
    public fileprivate(set) var drawerPosition: PulleyPosition = .collapsed {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    // The visible height of the drawer. Useful for adjusting the display of content in the main content view.
    public var visibleDrawerHeight: CGFloat {
        if drawerPosition == .closed {
            return 0.0
        } else {
            return drawerScrollView.bounds.height
        }
    }
    
    /// The background visual effect layer for the drawer. By default this is the extraLight effect. You can change this if you want, or assign nil to remove it.
    public var drawerBackgroundVisualEffectView: UIVisualEffectView? = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight)) {
        willSet {
            drawerBackgroundVisualEffectView?.removeFromSuperview()
        }
        didSet {
            
            if let drawerBackgroundVisualEffectView = drawerBackgroundVisualEffectView, self.isViewLoaded
            {
                drawerScrollView.insertSubview(drawerBackgroundVisualEffectView, aboveSubview: drawerShadowView)
                drawerBackgroundVisualEffectView.clipsToBounds = true
                drawerBackgroundVisualEffectView.layer.cornerRadius = drawerCornerRadius
            }
        }
    }
    
    /// The inset from the top safe area when fully open.
    @IBInspectable public var topInset: CGFloat = 20.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The corner radius for the drawer.
    @IBInspectable public var drawerCornerRadius: CGFloat = 13.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
                drawerBackgroundVisualEffectView?.layer.cornerRadius = drawerCornerRadius
            }
        }
    }
    
    /// The opacity of the drawer shadow.
    @IBInspectable public var shadowOpacity: Float = 0.1 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The radius of the drawer shadow.
    @IBInspectable public var shadowRadius: CGFloat = 3.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The opaque color of the background dimming view.
    @IBInspectable public var backgroundDimmingColor: UIColor = UIColor.black {
        didSet {
            if self.isViewLoaded
            {
                backgroundDimmingView.backgroundColor = backgroundDimmingColor
            }
        }
    }
    
    /// The maximum amount of opacity when dimming.
    @IBInspectable public var backgroundDimmingOpacity: CGFloat = 0.5 {
        didSet {
            
            if self.isViewLoaded
            {
                self.scrollViewDidScroll(drawerScrollView)
            }
        }
    }
    
    @IBInspectable public var delaysContentTouches: Bool = true {
        didSet {
            if self.isViewLoaded
            {
                drawerScrollView.delaysContentTouches = delaysContentTouches
            }
        }
    }
    
    @IBInspectable public var canCancelContentTouches: Bool = true {
        didSet {
            if self.isViewLoaded
            {
                drawerScrollView.canCancelContentTouches = canCancelContentTouches
            }
        }
    }
    
    /// The starting position for the drawer when it first loads
    public var initialDrawerPosition: PulleyPosition = .collapsed
    
    /// This is here exclusively to support IBInspectable in Interface Builder because Interface Builder can't deal with enums. If you're doing this in code use the -initialDrawerPosition property instead. Available strings are: open, closed, partiallyRevealed, collapsed
    @IBInspectable public var initialDrawerPositionFromIB: String? {
        didSet {
            initialDrawerPosition = PulleyPosition.positionFor(string: initialDrawerPositionFromIB)
        }
    }

    /// Whether the drawer's position can be changed by the user. If set to `false`, the only way to move the drawer is programmatically. Defaults to `true`.
    @IBInspectable public var allowsUserDrawerPositionChange: Bool = true {
        didSet {
            enforceCanScrollDrawer()
        }
    }
    
    // withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: .curveEaseInOut,

    @IBInspectable public var animationDuration: TimeInterval = 0.3
    
    @IBInspectable public var animationDelay: TimeInterval = 0.0
    
    @IBInspectable public var animationSpringDamping: CGFloat = 0.75
    
    @IBInspectable public var animationSpringInitialVelocity: CGFloat = 0.0
    
    public var animationOptions: UIViewAnimationOptions = [.curveEaseInOut]
    
    /// The drawer positions supported by the drawer
    fileprivate var supportedPositions: [PulleyPosition] = PulleyPosition.all {
        didSet {
            
            guard self.isViewLoaded else {
                return
            }
            
            guard supportedPositions.count > 0 else {
                supportedPositions = PulleyPosition.all
                return
            }
            
            self.view.setNeedsLayout()
            
            if supportedPositions.contains(drawerPosition)
            {
                setDrawerPosition(position: drawerPosition)
            }
            else
            {
                let lowestDrawerState: PulleyPosition = supportedPositions.min { (pos1, pos2) -> Bool in
                    return pos1.rawValue < pos2.rawValue
                    } ?? .collapsed
                
                setDrawerPosition(position: lowestDrawerState, animated: false)
            }
            
            enforceCanScrollDrawer()
        }
    }
    
    /**
     Initialize the drawer controller programmtically.
     
     - parameter contentViewController: The content view controller. This view controller is shown behind the drawer.
     - parameter drawerViewController:  The view controller to display inside the drawer.
     
     - note: The drawer VC is 20pts too tall in order to have some extra space for the bounce animation. Make sure your constraints / content layout take this into account.
     
     - returns: A newly created Pulley drawer.
     */
    required public init(contentViewController: UIViewController, drawerViewController: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        
        ({
            self.primaryContentViewController = contentViewController
            self.drawerContentViewController = drawerViewController
        })()
    }
    
    /**
     Initialize the drawer controller from Interface Builder.
     
     - note: Usage notes: Make 2 container views in Interface Builder and connect their outlets to -primaryContentContainerView and -drawerContentContainerView. Then use embed segues to place your content/drawer view controllers into the appropriate container.
     
     - parameter aDecoder: The NSCoder to decode from.
     
     - returns: A newly created Pulley drawer.
     */
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func loadView() {
        super.loadView()
        
        // IB Support
        if primaryContentContainerView != nil
        {
            primaryContentContainerView.removeFromSuperview()
        }
        
        if drawerContentContainerView != nil
        {
            drawerContentContainerView.removeFromSuperview()
        }
        
        // Setup
        primaryContentContainer.backgroundColor = UIColor.white
        
        definesPresentationContext = true
        
        drawerScrollView.bounces = false
        drawerScrollView.delegate = self
        drawerScrollView.clipsToBounds = false
        drawerScrollView.showsVerticalScrollIndicator = false
        drawerScrollView.showsHorizontalScrollIndicator = false
        
        drawerScrollView.delaysContentTouches = delaysContentTouches
        drawerScrollView.canCancelContentTouches = canCancelContentTouches
        
        drawerScrollView.backgroundColor = UIColor.clear
        drawerScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        drawerScrollView.scrollsToTop = false
        drawerScrollView.touchDelegate = self
        
        drawerShadowView.layer.shadowOpacity = shadowOpacity
        drawerShadowView.layer.shadowRadius = shadowRadius
        drawerShadowView.backgroundColor = UIColor.clear
        
        drawerContentContainer.backgroundColor = UIColor.clear
        
        backgroundDimmingView.backgroundColor = backgroundDimmingColor
        backgroundDimmingView.isUserInteractionEnabled = false
        backgroundDimmingView.alpha = 0.0
        
        drawerBackgroundVisualEffectView?.clipsToBounds = true
        
        dimmingViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PulleyViewController.dimmingViewTapRecognizerAction(gestureRecognizer:)))
        backgroundDimmingView.addGestureRecognizer(dimmingViewTapRecognizer!)
        
        drawerScrollView.addSubview(drawerShadowView)
        
        if let drawerBackgroundVisualEffectView = drawerBackgroundVisualEffectView
        {
            drawerScrollView.addSubview(drawerBackgroundVisualEffectView)
            drawerBackgroundVisualEffectView.layer.cornerRadius = drawerCornerRadius
        }
        
        drawerScrollView.addSubview(drawerContentContainer)
        
        primaryContentContainer.backgroundColor = UIColor.white
        
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(primaryContentContainer)
        self.view.addSubview(backgroundDimmingView)
        self.view.addSubview(drawerScrollView)
        
        primaryContentContainer.constrainToParent()
        
        backgroundDimmingView.constrainToParent()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // IB Support
        if primaryContentViewController == nil || drawerContentViewController == nil
        {
            assert(primaryContentContainerView != nil && drawerContentContainerView != nil, "When instantiating from Interface Builder you must provide container views with an embedded view controller.")
            
            // Locate main content VC
            for child in self.childViewControllers
            {
                if child.view == primaryContentContainerView.subviews.first
                {
                    primaryContentViewController = child
                }
                
                if child.view == drawerContentContainerView.subviews.first
                {
                    drawerContentViewController = child
                }
            }
            
            assert(primaryContentViewController != nil && drawerContentViewController != nil, "Container views must contain an embedded view controller.")
        }

        enforceCanScrollDrawer()
        setDrawerPosition(position: initialDrawerPosition, animated: false)
        scrollViewDidScroll(drawerScrollView)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setNeedsSupportedDrawerPositionsUpdate()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Make sure our view controller views are subviews of the right view (Resolves #21 issue with changing the presentation context)
        
        // May be nil during initial layout
        if let primary = primaryContentViewController
        {
            if primary.view.superview != nil && primary.view.superview != primaryContentContainer
            {
                primaryContentContainer.addSubview(primary.view)
                primaryContentContainer.sendSubview(toBack: primary.view)
                
                primary.view.constrainToParent()
            }
        }
        
        // May be nil during initial layout
        if let drawer = drawerContentViewController
        {
            if drawer.view.superview != nil && drawer.view.superview != drawerContentContainer
            {
                drawerContentContainer.addSubview(drawer.view)
                drawerContentContainer.sendSubview(toBack: drawer.view)
                
                drawer.view.constrainToParent()
            }
        }
        
        let safeAreaTopInset: CGFloat
        let safeAreaBottomInset: CGFloat
        var safeAreaLeftInset: CGFloat = 0
        var safeAreaRightInset: CGFloat = 0
        
        if #available(iOS 11.0, *)
        {
            safeAreaTopInset = self.view.safeAreaInsets.top
            safeAreaBottomInset = self.view.safeAreaInsets.bottom
            safeAreaLeftInset = view.safeAreaInsets.left
            safeAreaRightInset = view.safeAreaInsets.right
        }
        else
        {
            safeAreaTopInset = self.topLayoutGuide.length
            safeAreaBottomInset = self.bottomLayoutGuide.length
        }
        // Bottom inset for safe area / bottomLayoutGuid
        if #available(iOS 11, *) {
            self.drawerScrollView.contentInsetAdjustmentBehavior = .always
        } else {
            self.automaticallyAdjustsScrollViewInsets = false
            self.drawerScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.bottomLayoutGuide.length, right: 0)
            self.drawerScrollView.scrollIndicatorInsets =  UIEdgeInsets(top: 0, left: 0, bottom: self.bottomLayoutGuide.length, right: 0) // (usefull if visible..)
        }
        
        // Layout container
        var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
        var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
        
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            collapsedHeight = drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: safeAreaBottomInset)
            partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: safeAreaBottomInset)
        }

        let lowestStop = [(self.view.bounds.size.height - topInset - safeAreaTopInset), collapsedHeight, partialRevealHeight].min() ?? 0
        let bounceOverflowMargin: CGFloat = 20.0
        
        if supportedPositions.contains(.open)
        {
            // Layout scrollview
            drawerScrollView.frame = CGRect(x: safeAreaLeftInset, y: topInset + safeAreaTopInset, width: self.view.bounds.width - safeAreaLeftInset - safeAreaRightInset, height: self.view.bounds.height - topInset - safeAreaTopInset)
        }
        else
        {
            // Layout scrollview
            let adjustedTopInset: CGFloat = supportedPositions.contains(.partiallyRevealed) ? partialRevealHeight : collapsedHeight
            drawerScrollView.frame = CGRect(x: safeAreaLeftInset, y: self.view.bounds.height - adjustedTopInset, width: self.view.bounds.width - safeAreaLeftInset - safeAreaRightInset, height: adjustedTopInset)
        }
        
        drawerContentContainer.frame = CGRect(x: 0, y: drawerScrollView.bounds.height - lowestStop, width: drawerScrollView.bounds.width, height: drawerScrollView.bounds.height + bounceOverflowMargin)
        drawerBackgroundVisualEffectView?.frame = drawerContentContainer.frame
        drawerShadowView.frame = drawerContentContainer.frame
        drawerScrollView.contentSize = CGSize(width: drawerScrollView.bounds.width, height: (drawerScrollView.bounds.height - lowestStop) + drawerScrollView.bounds.height - safeAreaBottomInset)
        
        // Update rounding mask and shadows
        let borderPath = UIBezierPath(roundedRect: drawerContentContainer.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: drawerCornerRadius, height: drawerCornerRadius)).cgPath
        
        let cardMaskLayer = CAShapeLayer()
        cardMaskLayer.path = borderPath
        cardMaskLayer.frame = drawerContentContainer.bounds
        cardMaskLayer.fillColor = UIColor.white.cgColor
        cardMaskLayer.backgroundColor = UIColor.clear.cgColor
        drawerContentContainer.layer.mask = cardMaskLayer
        drawerShadowView.layer.shadowPath = borderPath
        
        maskBackgroundDimmingView()
        
        setDrawerPosition(position: drawerPosition, animated: false)
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Private State Updates

    private func enforceCanScrollDrawer() {
        guard isViewLoaded else {
            return
        }
        drawerScrollView.isScrollEnabled = allowsUserDrawerPositionChange && supportedPositions.count > 1
    }
    
    private func getBottomSafeArea() -> CGFloat {
        
        let safeAreaBottomInset: CGFloat
        
        if #available(iOS 11.0, *)
        {
            safeAreaBottomInset = self.view.safeAreaInsets.bottom
        }
        else
        {
            safeAreaBottomInset = self.bottomLayoutGuide.length
        }
        
        return safeAreaBottomInset
    }
    
    /**
     Mask backgroundDimmingView layer to avoid drawer background beeing darkened.
     */
    private func maskBackgroundDimmingView() {
        let cutoutHeight = 2 * drawerCornerRadius
        let maskHeight = backgroundDimmingView.bounds.size.height - cutoutHeight
        let drawerRect = CGRect(x: 0,
                                y: maskHeight,
                                width: backgroundDimmingView.bounds.size.width,
                                height: cutoutHeight)
        let path = UIBezierPath(roundedRect: drawerRect,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: drawerCornerRadius, height: drawerCornerRadius))
        let maskLayer = CAShapeLayer()
        
        // Invert mask to cut away the bottom part of the dimming view
        path.append(UIBezierPath(rect: backgroundDimmingView.bounds))
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        maskLayer.path = path.cgPath
        backgroundDimmingView.layer.mask = maskLayer
    }
    
    /**
     Get a frame for moving backgroundDimmingView according to drawer position.
     
     - parameter drawerPosition: drawer position in points
     
     - returns: a frame for moving backgroundDimmingView according to drawer position
     */
    private func backgroundDimmingViewFrameForDrawerPosition(_ drawerPosition: CGFloat) -> CGRect {
        let cutoutHeight = (2 * drawerCornerRadius)
        var backgroundDimmingViewFrame = backgroundDimmingView.frame
        backgroundDimmingViewFrame.origin.y = 0 - drawerPosition + cutoutHeight

        return backgroundDimmingViewFrame
    }

    // MARK: Configuration Updates
    
    /**
     Set the drawer position, with an option to animate.
     
     - parameter position: The position to set the drawer to.
     - parameter animated: Whether or not to animate the change. (Default: true)
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called. (Default: nil)
     */
    public func setDrawerPosition(position: PulleyPosition, animated: Bool, completion: PulleyAnimationCompletionBlock? = nil) {
        guard supportedPositions.contains(position) else {
            
            print("PulleyViewController: You can't set the drawer position to something not supported by the current view controller contained in the drawer. If you haven't already, you may need to implement the PulleyDrawerViewControllerDelegate.")
            return
        }
        
        drawerPosition = position
        
        var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
        var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
        
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            collapsedHeight = drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: getBottomSafeArea())
            partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: getBottomSafeArea())
        }

        let stopToMoveTo: CGFloat
        
        switch drawerPosition {
            
        case .collapsed:
            stopToMoveTo = collapsedHeight
            
        case .partiallyRevealed:
            stopToMoveTo = partialRevealHeight
            
        case .open:
            stopToMoveTo = (self.drawerScrollView.bounds.height)
            
        case .closed:
            stopToMoveTo = 0
        }
        
        let drawerStops = [(self.drawerScrollView.bounds.height), collapsedHeight, partialRevealHeight]
        let lowestStop = drawerStops.min() ?? 0
        
        if animated
        {
            UIView.animate(withDuration: animationDuration, delay: animationDelay, usingSpringWithDamping: animationSpringDamping, initialSpringVelocity: animationSpringInitialVelocity, options: animationOptions, animations: { [weak self] () -> Void in
                
                self?.drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
                
                // Move backgroundDimmingView to avoid drawer background beeing darkened
                self?.backgroundDimmingView.frame = self?.backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo) ?? CGRect.zero
                
                if let drawer = self
                {
                    drawer.delegate?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    (drawer.drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    (drawer.primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    
                    drawer.view.layoutIfNeeded()
                }
                
                }, completion: { (completed) in
                    
                    completion?(completed)
            })
        }
        else
        {
            drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
            
            // Move backgroundDimmingView to avoid drawer background beeing darkened
            backgroundDimmingView.frame = backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo)
            
            delegate?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())
            
            completion?(true)
        }
    }
    
    /**
     Set the drawer position, the change will be animated.
     
     - parameter position: The position to set the drawer to.
     */
    public func setDrawerPosition(position: PulleyPosition)
    {
        setDrawerPosition(position: position, animated: true)
    }
    
    /**
     Change the current primary content view controller (The one behind the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change. Defaults to true.
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called.
     */
    public func setPrimaryContentViewController(controller: UIViewController, animated: Bool = true, completion: PulleyAnimationCompletionBlock?)
    {
        // Account for transition issue in iOS 11
        controller.view.frame = primaryContentContainer.bounds
        controller.view.layoutIfNeeded()
        
        if animated
        {
            UIView.transition(with: primaryContentContainer, duration: 0.5, options: .transitionCrossDissolve, animations: { [weak self] () -> Void in
                
                self?.primaryContentViewController = controller
                
                }, completion: { (completed) in
                    
                    completion?(completed)
            })
        }
        else
        {
            primaryContentViewController = controller
            completion?(true)
        }
    }
    
    /**
     Change the current primary content view controller (The one behind the drawer). This method exists for backwards compatibility.
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change. Defaults to true.
     */
    public func setPrimaryContentViewController(controller: UIViewController, animated: Bool = true)
    {
        setPrimaryContentViewController(controller: controller, animated: animated, completion: nil)
    }
    
    /**
     Change the current drawer content view controller (The one inside the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change.
     - parameter completion: A block object to be executed when the animation sequence ends. The Bool indicates whether or not the animations actually finished before the completion handler was called.
     */
    public func setDrawerContentViewController(controller: UIViewController, animated: Bool = true, completion: PulleyAnimationCompletionBlock?)
    {
        // Account for transition issue in iOS 11
        controller.view.frame = drawerContentContainer.bounds
        controller.view.layoutIfNeeded()
        
        if animated
        {
            UIView.transition(with: drawerContentContainer, duration: 0.5, options: .transitionCrossDissolve, animations: { [weak self] () -> Void in
                
                self?.drawerContentViewController = controller
                self?.setDrawerPosition(position: self?.drawerPosition ?? .collapsed, animated: false)
                
                }, completion: { (completed) in
                    
                    completion?(completed)
            })
        }
        else
        {
            drawerContentViewController = controller
            setDrawerPosition(position: drawerPosition, animated: false)
            
            completion?(true)
        }
    }
    
    /**
     Change the current drawer content view controller (The one inside the drawer). This method exists for backwards compatibility.
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change.
     */
    public func setDrawerContentViewController(controller: UIViewController, animated: Bool = true)
    {
        setDrawerContentViewController(controller: controller, animated: animated, completion: nil)
    }
    
    /**
     Update the supported drawer positions allows by the Pulley Drawer
     */
    public func setNeedsSupportedDrawerPositionsUpdate()
    {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            supportedPositions = drawerVCCompliant.supportedDrawerPositions()
        }
        else
        {
            supportedPositions = PulleyPosition.all
        }
    }
    
    // MARK: Actions
    
    @objc func dimmingViewTapRecognizerAction(gestureRecognizer: UITapGestureRecognizer)
    {
        if gestureRecognizer == dimmingViewTapRecognizer
        {
            if gestureRecognizer.state == .ended
            {
                self.setDrawerPosition(position: .collapsed, animated: true)
            }
        }
    }
    
    // MARK: Propogate child view controller style / status bar presentation based on drawer state
    
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        get {
            
            if drawerPosition == .open {
                return drawerContentViewController
            }
            
            return primaryContentViewController
        }
    }
    
    override open var childViewControllerForStatusBarHidden: UIViewController? {
        get {
            if drawerPosition == .open {
                return drawerContentViewController
            }
            
            return primaryContentViewController
        }
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.notifyWhenInteractionEnds { [weak self] (_) in
            
            guard let currentPosition = self?.drawerPosition else {
                return
            }
            
            self?.setDrawerPosition(position: currentPosition, animated: false)
        }
    }
}

extension PulleyViewController: PulleyPassthroughScrollViewDelegate {
    
    func shouldTouchPassthroughScrollView(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> Bool
    {
        let contentDrawerLocation = drawerContentContainer.frame.origin.y
        
        if point.y < contentDrawerLocation
        {
            return true
        }
        
        return false
    }
    
    func viewToReceiveTouch(scrollView: PulleyPassthroughScrollView) -> UIView
    {
        if drawerPosition == .open
        {
            return backgroundDimmingView
        }
        
        return primaryContentContainer
    }
}

extension PulleyViewController: UIScrollViewDelegate {
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if scrollView == drawerScrollView
        {
            // Find the closest anchor point and snap there.
            var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
            var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
            
            if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
            {
                collapsedHeight = drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: getBottomSafeArea())
                partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: getBottomSafeArea())
            }

            var drawerStops: [CGFloat] = [CGFloat]()
            
            if supportedPositions.contains(.open)
            {
                drawerStops.append((self.drawerScrollView.bounds.height))
            }
            
            if supportedPositions.contains(.partiallyRevealed)
            {
                drawerStops.append(partialRevealHeight)
            }
            
            if supportedPositions.contains(.collapsed)
            {
                drawerStops.append(collapsedHeight)
            }
            
            let lowestStop = drawerStops.min() ?? 0
            
            let distanceFromBottomOfView = lowestStop + lastDragTargetContentOffset.y
            
            var currentClosestStop = lowestStop
            
            for currentStop in drawerStops
            {
                if abs(currentStop - distanceFromBottomOfView) < abs(currentClosestStop - distanceFromBottomOfView)
                {
                    currentClosestStop = currentStop
                }
            }
            
            if abs(Float(currentClosestStop - (self.drawerScrollView.bounds.height))) <= Float.ulpOfOne && supportedPositions.contains(.open)
            {
                setDrawerPosition(position: .open, animated: true)
            }
            else if abs(Float(currentClosestStop - collapsedHeight)) <= Float.ulpOfOne && supportedPositions.contains(.collapsed)
            {
                setDrawerPosition(position: .collapsed, animated: true)
            }
            else if supportedPositions.contains(.partiallyRevealed)
            {
                setDrawerPosition(position: .partiallyRevealed, animated: true)
            }
        }
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        if scrollView == drawerScrollView
        {
            lastDragTargetContentOffset = targetContentOffset.pointee
            
            // Halt intertia
            targetContentOffset.pointee = scrollView.contentOffset
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if scrollView == drawerScrollView
        {
            var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
            var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
            
            if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
            {
                collapsedHeight = drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: getBottomSafeArea())
                partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: getBottomSafeArea())
            }

            var drawerStops: [CGFloat] = [CGFloat]()
            
            if supportedPositions.contains(.open)
            {
                drawerStops.append((self.drawerScrollView.bounds.height))
            }
            
            if supportedPositions.contains(.partiallyRevealed)
            {
                drawerStops.append(partialRevealHeight)
            }
            
            if supportedPositions.contains(.collapsed)
            {
                drawerStops.append(collapsedHeight)
            }
            
            let lowestStop = drawerStops.min() ?? 0
            
            if scrollView.contentOffset.y > partialRevealHeight - lowestStop
            {
                // Calculate percentage between partial and full reveal
                let fullRevealHeight = (self.drawerScrollView.bounds.height)
                
                let progress = (scrollView.contentOffset.y - (partialRevealHeight - lowestStop)) / (fullRevealHeight - (partialRevealHeight))
                
                delegate?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: getBottomSafeArea())
                (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: getBottomSafeArea())
                (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: getBottomSafeArea())
                
                backgroundDimmingView.alpha = progress * backgroundDimmingOpacity
                
                backgroundDimmingView.isUserInteractionEnabled = true
            }
            else
            {
                if backgroundDimmingView.alpha >= 0.001
                {
                    backgroundDimmingView.alpha = 0.0
                    
                    delegate?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: getBottomSafeArea())
                    (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: getBottomSafeArea())
                    (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress: 0.0, bottomSafeArea: getBottomSafeArea())
                    
                    backgroundDimmingView.isUserInteractionEnabled = false
                }
            }
            
            delegate?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: getBottomSafeArea())
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: getBottomSafeArea())
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerChangedDistanceFromBottom?(drawer: self, distance: scrollView.contentOffset.y + lowestStop, bottomSafeArea: getBottomSafeArea())
            
            // Move backgroundDimmingView to avoid drawer background beeing darkened
            backgroundDimmingView.frame = backgroundDimmingViewFrameForDrawerPosition(scrollView.contentOffset.y + lowestStop)
        }
    }
}

