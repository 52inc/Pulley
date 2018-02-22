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
    
    /**
     *  Called when the current drawer display mode changes (leftSide vs bottomDrawer). Make UI changes to account for this here.
     */
    @objc optional func drawerDisplayModeDidChange(drawer: PulleyViewController)
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

/// Represents the current display mode for Pulley
///
/// - leftSide: Show as a floating panel on the left
/// - bottomDrawer: Show as a bottom drawer
/// - automatic: Determine it based on device / orientation / size class (like Maps.app)
public enum PulleyDisplayMode {
    case leftSide
    case bottomDrawer
    case automatic
}

/// Represents the 'snap' mode for Pulley. The default is 'nearest position'. You can use 'nearestPositionUnlessExceeded' to make the drawer feel lighter or heavier.
///
/// - nearestPosition: Snap to the nearest position when scroll stops
/// - nearestPositionUnlessExceeded: Snap to the nearest position when scroll stops, unless the distance is greater than 'threshold', in which case advance to the next drawer position.
public enum PulleySnapMode {
    case nearestPosition
    case nearestPositionUnlessExceeded(threshold: CGFloat)
}

private let kPulleyDefaultCollapsedHeight: CGFloat = 68.0
private let kPulleyDefaultPartialRevealHeight: CGFloat = 264.0

open class PulleyViewController: UIViewController, PulleyDrawerViewControllerDelegate {
    
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
    
    public let bounceOverflowMargin: CGFloat = 20.0

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
    
    /// The inset from the top safe area when fully open. NOTE: When in 'leftSide' displayMode this is the distance to the bottom of the screen.
    @IBInspectable public var topInset: CGFloat = 20.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// When in 'leftSide' displayMode, this is used to calculate the left inset from the edge of the screen.
    @IBInspectable public var panelInsetLeft: CGFloat = 10.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// When in 'leftSide' displayMode, this is used to calculate the top inset from the edge of the screen.
    @IBInspectable public var panelInsetTop: CGFloat = 30.0 {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The width of the panel in leftSide displayMode
    @IBInspectable public var panelWidth: CGFloat = 325.0 {
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
    
    /// The display mode for Pulley. Default is 'bottomDrawer', which preserves the previous behavior of Pulley. If you want it to adapt automatically, choose 'automatic'. The current display mode is available by using the 'currentDisplayMode' property.
    public var displayMode: PulleyDisplayMode = .bottomDrawer {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
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
    
    /// The animation duration for setting the drawer position
    @IBInspectable public var animationDuration: TimeInterval = 0.3
    
    /// The animation delay for setting the drawer position
    @IBInspectable public var animationDelay: TimeInterval = 0.0
    
    /// The spring damping for setting the drawer position
    @IBInspectable public var animationSpringDamping: CGFloat = 0.75
    
    /// The spring's initial velocity for setting the drawer position
    @IBInspectable public var animationSpringInitialVelocity: CGFloat = 0.0
    
    /// The animation options for setting the drawer position
    public var animationOptions: UIViewAnimationOptions = [.curveEaseInOut]
    
    /// The drawer snap mode
    public var snapMode: PulleySnapMode = .nearestPositionUnlessExceeded(threshold: 20.0)
    
    // The feedback generator to use for drawwer positon changes. Note: This is 'Any' to preserve iOS 9 compatibilty. Assign a UIFeedbackGenerator to this property. Anything else will be ignored.
    public var feedbackGenerator: Any?
    
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
                setDrawerPosition(position: drawerPosition, animated: true)
            }
            else
            {
                let lowestDrawerState: PulleyPosition = supportedPositions.filter({ $0 != .closed }).min { (pos1, pos2) -> Bool in
                    return pos1.rawValue < pos2.rawValue
                    } ?? .collapsed
                
                setDrawerPosition(position: lowestDrawerState, animated: false)
            }
            
            enforceCanScrollDrawer()
        }
    }
    
    /// The currently rendered display mode for Pulley. This will match displayMode unless you have it set to 'automatic'. This will provide the 'actual' display mode (never automatic).
    public fileprivate(set) var currentDisplayMode: PulleyDisplayMode = .automatic {
        didSet {
            if self.isViewLoaded
            {
                self.view.setNeedsLayout()
            }
            
            if oldValue != currentDisplayMode
            {
                delegate?.drawerDisplayModeDidChange?(drawer: self)
                (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self)
                (primaryContentContainer as? PulleyPrimaryContentControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self)
            }
        }
    }
    
    fileprivate var isAnimatingDrawerPosition: Bool = false
    
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
        
        delegate?.drawerDisplayModeDidChange?(drawer: self)
        (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self)
        (primaryContentContainer as? PulleyPrimaryContentControllerDelegate)?.drawerDisplayModeDidChange?(drawer: self)
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
        let safeAreaLeftInset = getLeftSafeArea()
        let safeAreaRightInset = getRightSafeArea()
        
        if #available(iOS 11.0, *)
        {
            safeAreaTopInset = self.view.safeAreaInsets.top
            safeAreaBottomInset = self.view.safeAreaInsets.bottom
        }
        else
        {
            safeAreaTopInset = self.topLayoutGuide.length
            safeAreaBottomInset = self.bottomLayoutGuide.length
        }
        
        let displayModeForCurrentLayout: PulleyDisplayMode = displayMode != .automatic ? displayMode : ((self.view.bounds.width >= 600.0 || self.traitCollection.horizontalSizeClass == .regular) ? .leftSide : .bottomDrawer)
        
        currentDisplayMode = displayModeForCurrentLayout
        
        if displayModeForCurrentLayout == .bottomDrawer
        {
            // Bottom inset for safe area / bottomLayoutGuide
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
            
            drawerScrollView.addSubview(drawerShadowView)
            
            if let drawerBackgroundVisualEffectView = drawerBackgroundVisualEffectView
            {
                drawerScrollView.addSubview(drawerBackgroundVisualEffectView)
                drawerBackgroundVisualEffectView.layer.cornerRadius = drawerCornerRadius
            }
            
            drawerScrollView.addSubview(drawerContentContainer)
            
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
            
            backgroundDimmingView.frame = CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: self.view.bounds.height + drawerScrollView.contentSize.height)
            
            drawerScrollView.transform = CGAffineTransform.identity
            
            backgroundDimmingView.isHidden = false
        }
        else
        {
            // Bottom inset for safe area / bottomLayoutGuide
            if #available(iOS 11, *) {
                self.drawerScrollView.contentInsetAdjustmentBehavior = .always
            } else {
                self.automaticallyAdjustsScrollViewInsets = false
                self.drawerScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0.0, right: 0)
                self.drawerScrollView.scrollIndicatorInsets =  UIEdgeInsets(top: 0, left: 0, bottom: 0.0, right: 0)
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
            
            if supportedPositions.contains(.open)
            {
                // Layout scrollview
                drawerScrollView.frame = CGRect(x: safeAreaLeftInset + panelInsetLeft, y: panelInsetTop + safeAreaTopInset, width: panelWidth, height: self.view.bounds.height - topInset - safeAreaTopInset - panelInsetTop)
            }
            else
            {
                // Layout scrollview
                let adjustedTopInset: CGFloat = supportedPositions.contains(.partiallyRevealed) ? partialRevealHeight : collapsedHeight
                drawerScrollView.frame = CGRect(x: safeAreaLeftInset + panelInsetLeft, y: panelInsetTop + safeAreaTopInset, width: panelWidth, height: adjustedTopInset)
            }

            syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
            
            drawerScrollView.contentSize = CGSize(width: drawerScrollView.bounds.width, height: self.view.bounds.height + (self.view.bounds.height - lowestStop))
            
            drawerScrollView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            backgroundDimmingView.isHidden = true
        }
        
        drawerContentContainer.transform = drawerScrollView.transform
        drawerShadowView.transform = drawerScrollView.transform
        
        maskBackgroundDimmingView()
        setDrawerPosition(position: drawerPosition, animated: false)
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

    private func getLeftSafeArea() -> CGFloat {

        var safeAreaLeftInset: CGFloat = 0

        if #available(iOS 11.0, *)
        {
            safeAreaLeftInset = view.safeAreaInsets.left
        }

        return safeAreaLeftInset
    }

    private func getRightSafeArea() -> CGFloat {

        var safeAreaRightInset: CGFloat = 0

        if #available(iOS 11.0, *)
        {
            safeAreaRightInset = view.safeAreaInsets.right
        }

        return safeAreaRightInset
    }
    
    /**
     Mask backgroundDimmingView layer to avoid drawer background beeing darkened.
     */
    private func maskBackgroundDimmingView() {
        
        let cutoutHeight = 2 * drawerCornerRadius
        let maskHeight = backgroundDimmingView.bounds.size.height - cutoutHeight - drawerScrollView.contentSize.height
        let maskWidth = backgroundDimmingView.bounds.width - getLeftSafeArea() - getRightSafeArea()
        let drawerRect = CGRect(x: getLeftSafeArea(), y: maskHeight, width: maskWidth, height: drawerContentContainer.bounds.height)
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
    
    open func prepareFeedbackGenerator() {
        
        if #available(iOS 10.0, *) {
            if let generator = feedbackGenerator as? UIFeedbackGenerator
            {
                generator.prepare()
            }
        }
    }
    
    open func triggerFeedbackGenerator() {
        
        if #available(iOS 10.0, *) {
            
            prepareFeedbackGenerator()
            
            (feedbackGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
            (feedbackGenerator as? UISelectionFeedbackGenerator)?.selectionChanged()
            (feedbackGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
        }
    }
    
    /// Bounce the drawer to get user attention. Note: Only works in .bottomDrawer display mode and when the drawer is in .collapsed or .partiallyRevealed position.
    ///
    /// - Parameters:
    ///   - bounceHeight: The height to bounce
    ///   - speedMultiplier: The multiplier to apply to the default speed of the animation. Note, default speed is 0.75.
    public func bounceDrawer(bounceHeight: CGFloat = 50.0, speedMultiplier: Double = 0.75) {
        
        guard drawerPosition == .collapsed || drawerPosition == .partiallyRevealed else {
            print("Pulley: Error: You can only bounce the drawer when it's in the collapsed or partially revealed position.")
            return
        }
        
        guard currentDisplayMode == .bottomDrawer else {
            print("Pulley: Error: You can only bounce the drawer when it's in the .bottomDrawer display mode.")
            return
        }
        
        let drawerStartingBounds = drawerScrollView.bounds
        
        // Adapted from https://www.cocoanetics.com/2012/06/lets-bounce/
        let factors: [CGFloat] = [0, 32, 60, 83, 100, 114, 124, 128, 128, 124, 114, 100, 83, 60, 32,
            0, 24, 42, 54, 62, 64, 62, 54, 42, 24, 0, 18, 28, 32, 28, 18, 0]
        
        var values = [CGFloat]()
        
        for factor in factors
        {
            let positionOffset = (factor / 128.0) * bounceHeight
            values.append(drawerStartingBounds.origin.y + positionOffset)
        }
        
        let animation = CAKeyframeAnimation(keyPath: "bounds.origin.y")
        animation.repeatCount = 1
        animation.duration = (32.0/30.0) * speedMultiplier
        animation.fillMode = kCAFillModeForwards
        animation.values = values
        animation.isRemovedOnCompletion = true
        animation.autoreverses = false
        
        drawerScrollView.layer.add(animation, forKey: "bounceAnimation")
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
    
    private func syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode() {
        
        guard currentDisplayMode == .leftSide else {
            return
        }
        
        let safeAreaTopInset: CGFloat
        let safeAreaBottomInset: CGFloat
        
        if #available(iOS 11.0, *)
        {
            safeAreaTopInset = self.view.safeAreaInsets.top
            safeAreaBottomInset = self.view.safeAreaInsets.bottom
        }
        else
        {
            safeAreaTopInset = self.topLayoutGuide.length
            safeAreaBottomInset = self.bottomLayoutGuide.length
        }
        
        var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
        var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
        
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            collapsedHeight = drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: safeAreaBottomInset)
            partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: safeAreaBottomInset)
        }
        
        let lowestStop = [(self.view.bounds.size.height - topInset - safeAreaTopInset), collapsedHeight, partialRevealHeight].min() ?? 0
        
        drawerContentContainer.frame = CGRect(x: 0.0, y: drawerScrollView.bounds.height - lowestStop , width: drawerScrollView.bounds.width, height: drawerScrollView.contentOffset.y + lowestStop + bounceOverflowMargin)
        drawerBackgroundVisualEffectView?.frame = drawerContentContainer.frame
        drawerShadowView.frame = drawerContentContainer.frame
        
        // Update rounding mask and shadows
        let borderPath = UIBezierPath(roundedRect: drawerContentContainer.bounds, byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight], cornerRadii: CGSize(width: drawerCornerRadius, height: drawerCornerRadius)).cgPath
        
        let cardMaskLayer = CAShapeLayer()
        cardMaskLayer.path = borderPath
        cardMaskLayer.frame = drawerContentContainer.bounds
        cardMaskLayer.fillColor = UIColor.white.cgColor
        cardMaskLayer.backgroundColor = UIColor.clear.cgColor
        drawerContentContainer.layer.mask = cardMaskLayer
        
        if !isAnimatingDrawerPosition || borderPath.boundingBox.height < drawerShadowView.layer.shadowPath?.boundingBox.height ?? 0.0
        {
            drawerShadowView.layer.shadowPath = borderPath
        }
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
        
        triggerFeedbackGenerator()
        
        if animated
        {
            isAnimatingDrawerPosition = true
            UIView.animate(withDuration: animationDuration, delay: animationDelay, usingSpringWithDamping: animationSpringDamping, initialSpringVelocity: animationSpringInitialVelocity, options: animationOptions, animations: { [weak self] () -> Void in
                
                self?.drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
                
                // Move backgroundDimmingView to avoid drawer background being darkened
                self?.backgroundDimmingView.frame = self?.backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo) ?? CGRect.zero
                
                if let drawer = self
                {
                    drawer.delegate?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    (drawer.drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    (drawer.primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: self?.getBottomSafeArea() ?? 0.0)
                    
                    drawer.view.layoutIfNeeded()
                }

                }, completion: { [weak self] (completed) in
                    
                    self?.isAnimatingDrawerPosition = false
                    self?.syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
                    
                    completion?(completed)
            })
        }
        else
        {
            drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
            
            // Move backgroundDimmingView to avoid drawer background being darkened
            backgroundDimmingView.frame = backgroundDimmingViewFrameForDrawerPosition(stopToMoveTo)
            
            delegate?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer: self, bottomSafeArea: getBottomSafeArea())

            completion?(true)
        }
    }
    
    /**
     Set the drawer position, by default the change will be animated. Deprecated. Recommend switching to the other setDrawerPosition method, this one will be removed in a future release.
     
     - parameter position: The position to set the drawer to.
     - parameter isAnimated: Whether or not to animate the change. Default: true
     */
    @available(*, deprecated)
    public func setDrawerPosition(position: PulleyPosition, isAnimated: Bool = true)
    {
        setDrawerPosition(position: position, animated: isAnimated)
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
    
    // MARK: PulleyDrawerViewControllerDelegate implementation for nested Pulley view controllers in drawers. Implemented here, rather than an extension because overriding extensions in subclasses isn't good practice. Some developers want to subclass Pulley and customize these behaviors, so we'll move them here.
    
    open func collapsedDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.collapsedDrawerHeight(bottomSafeArea: bottomSafeArea)
        } else {
            return 68.0 + bottomSafeArea
        }
    }
    
    open func partialRevealDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.partialRevealDrawerHeight(bottomSafeArea: bottomSafeArea)
        } else {
            return 264.0 + bottomSafeArea
        }
    }
    
    open func supportedDrawerPositions() -> [PulleyPosition] {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.supportedDrawerPositions()
        } else {
            return PulleyPosition.all
        }
    }
    
    open func drawerPositionDidChange(drawer: PulleyViewController, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerPositionDidChange?(drawer: drawer, bottomSafeArea: bottomSafeArea)
        }
    }
    
    open func makeUIAdjustmentsForFullscreen(progress: CGFloat, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.makeUIAdjustmentsForFullscreen?(progress: progress, bottomSafeArea: bottomSafeArea)
        }
    }
    
    open func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerChangedDistanceFromBottom?(drawer: drawer, distance: distance, bottomSafeArea: bottomSafeArea)
        }
    }
}

extension PulleyViewController: PulleyPassthroughScrollViewDelegate {
    
    func shouldTouchPassthroughScrollView(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> Bool
    {
        return !drawerContentContainer.bounds.contains(drawerContentContainer.convert(point, from: scrollView))
    }
    
    func viewToReceiveTouch(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> UIView
    {
        if currentDisplayMode == .bottomDrawer
        {
            if drawerPosition == .open
            {
                return backgroundDimmingView
            }
            
            return primaryContentContainer
        }
        else
        {
            if drawerContentContainer.bounds.contains(drawerContentContainer.convert(point, from: scrollView))
            {
                return drawerContentViewController.view
            }
            
            return primaryContentContainer
        }
    }
}

extension PulleyViewController: UIScrollViewDelegate {
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        
    }
    
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
            var currentDrawerPositionStop: CGFloat = 0.0
            
            if supportedPositions.contains(.open)
            {
                drawerStops.append((self.drawerScrollView.bounds.height))
                
                if drawerPosition == .open
                {
                    currentDrawerPositionStop = drawerStops.last!
                }
            }
            
            if supportedPositions.contains(.partiallyRevealed)
            {
                drawerStops.append(partialRevealHeight)
                
                if drawerPosition == .partiallyRevealed
                {
                    currentDrawerPositionStop = drawerStops.last!
                }
            }
            
            if supportedPositions.contains(.collapsed)
            {
                drawerStops.append(collapsedHeight)
                
                if drawerPosition == .collapsed
                {
                    currentDrawerPositionStop = drawerStops.last!
                }
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
            
            var closestValidDrawerPosition: PulleyPosition = drawerPosition
            
            if abs(Float(currentClosestStop - (self.drawerScrollView.bounds.height))) <= Float.ulpOfOne && supportedPositions.contains(.open)
            {
                closestValidDrawerPosition = .open
            }
            else if abs(Float(currentClosestStop - collapsedHeight)) <= Float.ulpOfOne && supportedPositions.contains(.collapsed)
            {
                closestValidDrawerPosition = .collapsed
            }
            else if supportedPositions.contains(.partiallyRevealed)
            {
                closestValidDrawerPosition = .partiallyRevealed
            }
            
            let snapModeToUse: PulleySnapMode = closestValidDrawerPosition == drawerPosition ? snapMode : .nearestPosition
            
            switch snapModeToUse {
                
            case .nearestPosition:
                
                setDrawerPosition(position: closestValidDrawerPosition, animated: true)
                
            case .nearestPositionUnlessExceeded(let threshold):
                
                let distance = currentDrawerPositionStop - distanceFromBottomOfView
                
                var positionToSnapTo: PulleyPosition = drawerPosition

                if abs(distance) > threshold
                {
                    if distance < 0
                    {
                        let orderedSupportedDrawerPositions = supportedPositions.sorted(by: { $0.rawValue < $1.rawValue }).filter({ $0 != .closed })

                        for position in orderedSupportedDrawerPositions
                        {
                            if position.rawValue > drawerPosition.rawValue
                            {
                                positionToSnapTo = position
                                break
                            }
                        }
                    }
                    else
                    {
                        let orderedSupportedDrawerPositions = supportedPositions.sorted(by: { $0.rawValue > $1.rawValue }).filter({ $0 != .closed })
                        
                        for position in orderedSupportedDrawerPositions
                        {
                            if position.rawValue < drawerPosition.rawValue
                            {
                                positionToSnapTo = position
                                break
                            }
                        }
                    }
                }
                
                setDrawerPosition(position: positionToSnapTo, animated: true)
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

            // Collapsed is required for correct measurements here, as it's factored into the height of the drawer itself.
            drawerStops.append(collapsedHeight)
            
            let lowestStop = drawerStops.min() ?? 0
            
            if (scrollView.contentOffset.y - getBottomSafeArea()) > partialRevealHeight - lowestStop
            {
                // Calculate percentage between partial and full reveal
                let fullRevealHeight = (self.drawerScrollView.bounds.height)
                let progress: CGFloat
                if fullRevealHeight == partialRevealHeight {
                    progress = 1.0
                } else {
                    progress = (scrollView.contentOffset.y - (partialRevealHeight - lowestStop)) / (fullRevealHeight - (partialRevealHeight))
                }

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
            
            syncDrawerContentViewSizeToMatchScrollPositionForSideDisplayMode()
        }
    }
}

