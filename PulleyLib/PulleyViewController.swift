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
    
    optional func drawerPositionDidChange(drawer: PulleyViewController)
    optional func makeUIAdjustmentsForFullscreen(progress: CGFloat)
    optional func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat)
}

/**
 *  View controllers in the drawer can implement this to receive changes in state or provide values for the different drawer positions.
 */
public protocol PulleyDrawerViewControllerDelegate: PulleyDelegate {
    
    func collapsedDrawerHeight() -> CGFloat
    func partialRevealDrawerHeight() -> CGFloat
		func supportedDrawerPositions() -> [PulleyPosition]
}

/**
 *  View controllers that are the main content can implement this to receive changes in state.
 */
@objc public protocol PulleyPrimaryContentControllerDelegate: PulleyDelegate {
    
    // Not currently used for anything, but it's here for parity with the hopes that it'll one day be used.
}

/**
 Represents a Pulley drawer position.
 
 - Collapsed:         When the drawer is in its smallest form, at the bottom of the screen.
 - PartiallyRevealed: When the drawer is partially revealed.
 - Open:              When the drawer is fully open.
 */
public enum PulleyPosition: Int {
	
 case Collapsed = 0
 case PartiallyRevealed = 1
 case Open = 2
 
 public static var All: [PulleyPosition] = [
		 .Collapsed,
		 .PartiallyRevealed,
		 .Open
 ]
}
private let kPulleyDefaultCollapsedHeight: CGFloat = 68.0
private let kPulleyDefaultPartialRevealHeight: CGFloat = 264.0

public class PulleyViewController: UIViewController, UIScrollViewDelegate, PulleyPassthroughScrollViewDelegate {
    
    // Interface Builder
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet var primaryContentContainerView: UIView!
    
    /// When using with Interface Builder only! Connect a containing view to this outlet.
    @IBOutlet var drawerContentContainerView: UIView!
    
    // Internal
    private let primaryContentContainer: UIView = UIView()
    private let drawerContentContainer: UIView = UIView()
    private let drawerShadowView: UIView = UIView()
    private let drawerScrollView: PulleyPassthroughScrollView = PulleyPassthroughScrollView()
    private let backgroundDimmingView: UIView = UIView()
    
    private var dimmingViewTapRecognizer: UITapGestureRecognizer?
    
    /// The current content view controller (shown behind the drawer).
    private(set) var primaryContentViewController: UIViewController! {
        willSet {
            
            guard let controller = primaryContentViewController else {
                return;
            }
            
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = primaryContentViewController else {
                return;
            }
            
            controller.view.translatesAutoresizingMaskIntoConstraints = true
            
            self.primaryContentContainer.addSubview(controller.view)
            self.addChildViewController(controller)
            
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
								self.setNeedsSupportedDrawerPositionsUpdate()

            }
        }
    }
    
    /// The current drawer view controller (shown in the drawer).
    private(set) var drawerContentViewController: UIViewController! {
        willSet {
            
            guard let controller = drawerContentViewController else {
                return;
            }
            
            controller.view.removeFromSuperview()
            controller.removeFromParentViewController()
        }
        
        didSet {
            
            guard let controller = drawerContentViewController else {
                return;
            }
            
            controller.view.translatesAutoresizingMaskIntoConstraints = true
            
            self.drawerContentContainer.addSubview(controller.view)
            self.addChildViewController(controller)
            
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
								self.setNeedsSupportedDrawerPositionsUpdate()
            }
        }
    }
    
    /// The content view controller and drawer controller can receive delegate events already. This lets another object observe the changes, if needed.
    public weak var delegate: PulleyDelegate?
    
    /// The current position of the drawer.
	public private(set) var drawerPosition: PulleyPosition = .Collapsed{
		didSet {
			setNeedsStatusBarAppearanceUpdate()
		}
	}
	
	
	public var drawerBackgroundVisualEffectView: UIVisualEffectView? = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.ExtraLight)) {
		willSet {
			drawerBackgroundVisualEffectView?.removeFromSuperview()
		}
		didSet {
			
			if let drawerBackgroundVisualEffectView = drawerBackgroundVisualEffectView where self.isViewLoaded() == true
			{
				drawerScrollView.insertSubview(drawerBackgroundVisualEffectView, aboveSubview: drawerShadowView)
				drawerBackgroundVisualEffectView.clipsToBounds = true
				drawerBackgroundVisualEffectView.layer.cornerRadius = drawerCornerRadius
			}
		}
	}

	
    /// The inset from the top of the view controller when fully open.
    public var topInset: CGFloat = 50.0 {
        didSet {
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The corner radius for the drawer.
    public var drawerCornerRadius: CGFloat = 13.0 {
        didSet {
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
							drawerBackgroundVisualEffectView?.layer.cornerRadius = drawerCornerRadius
            }
        }
    }
    
    /// The opacity of the drawer shadow.
    public var shadowOpacity: Float = 0.1 {
        didSet {
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The radius of the drawer shadow.
    public var shadowRadius: CGFloat = 3.0 {
        didSet {
            if self.isViewLoaded()
            {
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// The opaque color of the background dimming view.
    public var backgroundDimmingColor: UIColor = UIColor.blackColor() {
        didSet {
            if self.isViewLoaded()
            {
                backgroundDimmingView.backgroundColor = backgroundDimmingColor
            }
        }
    }
    
    /// The maximum amount of opacity when dimming.
    public var backgroundDimmingOpacity: CGFloat = 0.5 {
        didSet {
            
            if self.isViewLoaded()
            {
                self.scrollViewDidScroll(drawerScrollView)
            }
        }
    }
	
	/// The drawer positions supported by the drawer
     private var supportedDrawerPositions: [PulleyPosition] = PulleyPosition.All {
         didSet {
 
             guard self.isViewLoaded() else {
                 return
             }
 
             guard supportedDrawerPositions.count > 0 else {
                 supportedDrawerPositions = PulleyPosition.All
                 return
             }
 
             self.view.setNeedsLayout()
 
             if supportedDrawerPositions.contains(drawerPosition)
             {
                 setDrawerPosition(drawerPosition)
             }
             else
             {
								let lowestDrawerState: PulleyPosition = supportedDrawerPositions.minElement({ (pos1, pos2) -> Bool in
									return pos1.rawValue < pos2.rawValue
								}) ?? .Collapsed
							
								setDrawerPosition(lowestDrawerState, animated: false)
             }
 
             drawerScrollView.scrollEnabled = supportedDrawerPositions.count > 1
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
    
    public override func loadView() {
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
        primaryContentContainer.backgroundColor = UIColor.whiteColor()
        
        drawerScrollView.bounces = false
        drawerScrollView.delegate = self
        drawerScrollView.clipsToBounds = false
        drawerScrollView.showsVerticalScrollIndicator = false
        drawerScrollView.showsHorizontalScrollIndicator = false
        drawerScrollView.delaysContentTouches = true
        drawerScrollView.canCancelContentTouches = true
        drawerScrollView.backgroundColor = UIColor.clearColor()
        drawerScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        drawerScrollView.touchDelegate = self
        
        drawerShadowView.layer.shadowOpacity = shadowOpacity
        drawerShadowView.layer.shadowRadius = shadowRadius
        drawerShadowView.backgroundColor = UIColor.clearColor()
        
        drawerContentContainer.backgroundColor = UIColor.clearColor()
        
        backgroundDimmingView.backgroundColor = backgroundDimmingColor
        backgroundDimmingView.userInteractionEnabled = false
        backgroundDimmingView.alpha = 0.0
			
				drawerBackgroundVisualEffectView?.clipsToBounds = true
			
        dimmingViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PulleyViewController.dimmingViewTapRecognizer(_:)))
        backgroundDimmingView.addGestureRecognizer(dimmingViewTapRecognizer!)
        
        drawerScrollView.addSubview(drawerShadowView)
			
				if let drawerBackgroundVisualEffectView = drawerBackgroundVisualEffectView {
					drawerScrollView.addSubview(drawerBackgroundVisualEffectView)
			    drawerBackgroundVisualEffectView.layer.cornerRadius = drawerCornerRadius
				}
			
        drawerScrollView.addSubview(drawerContentContainer)
        
        primaryContentContainer.backgroundColor = UIColor.whiteColor()
        
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.view.addSubview(primaryContentContainer)
        self.view.addSubview(backgroundDimmingView)
        self.view.addSubview(drawerScrollView)
    }
    
    public override func viewDidLoad() {
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
        
        scrollViewDidScroll(drawerScrollView)
    }
	
		override public func viewDidAppear(animated: Bool) {
			super.viewDidAppear(animated)
			setNeedsSupportedDrawerPositionsUpdate()
		}

	
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Layout main content
        primaryContentContainer.frame = self.view.bounds
        backgroundDimmingView.frame = self.view.bounds
        
        // Layout scrollview
//        drawerScrollView.frame = CGRect(x: 0, y: topInset, width: self.view.bounds.width, height: self.view.bounds.height - topInset)
			
        // Layout container
        var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
        var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
        
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            collapsedHeight = drawerVCCompliant.collapsedDrawerHeight()
            partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight()
        }
        
        let lowestStop = [(self.view.bounds.size.height - topInset), collapsedHeight, partialRevealHeight].minElement() ?? 0
        let bounceOverflowMargin: CGFloat = 20.0
			
			
				if supportedDrawerPositions.contains(.Open)
				{
						// Layout scrollview
						drawerScrollView.frame = CGRect(x: 0, y: topInset, width: self.view.bounds.width, height: self.view.bounds.height - topInset)
				}
				else
				{
						// Layout scrollview
						let adjustedTopInset: CGFloat = supportedDrawerPositions.contains(.PartiallyRevealed) ? partialRevealHeight : collapsedHeight
						drawerScrollView.frame = CGRect(x: 0, y: self.view.bounds.height - adjustedTopInset, width: self.view.bounds.width, height: adjustedTopInset)
				}
			
        drawerContentContainer.frame = CGRect(x: 0, y: drawerScrollView.bounds.height - lowestStop, width: drawerScrollView.bounds.width, height: drawerScrollView.bounds.height + bounceOverflowMargin)
				drawerBackgroundVisualEffectView?.frame = drawerContentContainer.frame
				drawerShadowView.frame = drawerContentContainer.frame
        drawerScrollView.contentSize = CGSize(width: drawerScrollView.bounds.width, height: (drawerScrollView.bounds.height - lowestStop) + drawerScrollView.bounds.height)
        
        // Update rounding mask and shadows
        let borderPath = UIBezierPath(roundedRect: drawerContentContainer.bounds, byRoundingCorners: [.TopLeft, .TopRight], cornerRadii: CGSize(width: drawerCornerRadius, height: drawerCornerRadius)).CGPath
        
        let cardMaskLayer = CAShapeLayer()
        cardMaskLayer.path = borderPath
				cardMaskLayer.frame = drawerContentContainer.bounds
        cardMaskLayer.fillColor = UIColor.whiteColor().CGColor
        cardMaskLayer.backgroundColor = UIColor.clearColor().CGColor
        drawerContentContainer.layer.mask = cardMaskLayer
        drawerShadowView.layer.shadowPath = borderPath
        
        // Make VC views match frames
			primaryContentViewController?.view.frame = primaryContentContainer.bounds
			drawerContentViewController?.view.frame = CGRect(x: drawerContentContainer.bounds.minX, y: drawerContentContainer.bounds.minY, width: drawerContentContainer.bounds.width, height: drawerContentContainer.bounds.height)			
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Configuration Updates
    
    /**
     Set the drawer position, with an option to animate.
     
     - parameter position: The position to set the drawer to.
     - parameter animated: Whether or not to animate the change. (Default: true)
     */
    public func setDrawerPosition(position: PulleyPosition, animated: Bool = true)
    {
				guard supportedDrawerPositions.contains(position) else {
				            return
				}
			
        drawerPosition = position
        
        var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
        var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
        
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
        {
            collapsedHeight = drawerVCCompliant.collapsedDrawerHeight()
            partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight()
        }
        
        let stopToMoveTo: CGFloat
        
        switch drawerPosition {
            
        case .Collapsed:
            stopToMoveTo = collapsedHeight
            
        case .PartiallyRevealed:
            stopToMoveTo = partialRevealHeight
            
        case .Open:
            stopToMoveTo = (self.view.bounds.size.height - topInset)
        }
        
        let drawerStops = [(self.view.bounds.size.height - topInset), collapsedHeight, partialRevealHeight]
        let lowestStop = drawerStops.minElement() ?? 0
        
        if animated
        {
            UIView.animateWithDuration(0.3, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: .CurveEaseInOut, animations: { [weak self] () -> Void in
                
                self?.drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
                
                if let drawer = self
                {
                    drawer.delegate?.drawerPositionDidChange?(drawer)
                    (drawer.drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(drawer)
                    (drawer.primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(drawer)
                    
                    drawer.view.layoutIfNeeded()
                }
                
                }, completion: nil)
        }
        else
        {
            drawerScrollView.setContentOffset(CGPoint(x: 0, y: stopToMoveTo - lowestStop), animated: false)
            
            delegate?.drawerPositionDidChange?(self)
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerPositionDidChange?(self)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerPositionDidChange?(self)
        }
    }
	
    /**
     Change the current primary content view controller (The one behind the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change. Defaults to true.
     */
    public func setPrimaryContentViewController(controller: UIViewController, animated: Bool = true)
    {
        if animated
        {
            UIView.transitionWithView(primaryContentContainer, duration: 0.5, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: { [weak self] () -> Void in
                
                self?.primaryContentViewController = controller
                
                }, completion: nil)
        }
        else
        {
            primaryContentViewController = controller
        }
    }
    
    /**
     Change the current drawer content view controller (The one inside the drawer)
     
     - parameter controller: The controller to replace it with
     - parameter animated:   Whether or not to animate the change.
     */
    public func setDrawerContentViewController(controller: UIViewController, animated: Bool = true)
    {
        if animated
        {
            UIView.transitionWithView(drawerContentContainer, duration: 0.5, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: { [weak self] () -> Void in
                
                self?.drawerContentViewController = controller
                self?.setDrawerPosition(self?.drawerPosition ?? .Collapsed, animated: false)
                
                }, completion: nil)
        }
        else
        {
            drawerContentViewController = controller
            setDrawerPosition(drawerPosition, animated: false)
        }
    }
	
		/**
		Update the supported drawer positions allows by the Pulley Drawer
		*/
		public func setNeedsSupportedDrawerPositionsUpdate()
		{
			if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
			{
				supportedDrawerPositions = drawerVCCompliant.supportedDrawerPositions()
			}
			else
			{
				supportedDrawerPositions = PulleyPosition.All
			}
		}

	
    // MARK: Actions
	
    func dimmingViewTapRecognizer(gestureRecognizer: UITapGestureRecognizer)
    {
        if gestureRecognizer == dimmingViewTapRecognizer
        {
            if gestureRecognizer.state == .Began
            {
                self.setDrawerPosition(.Collapsed, animated: true)
            }
        }
    }
    
    // MARK: UIScrollViewDelegate
    
    private var lastDragTargetContentOffset: CGPoint = CGPoint.zero
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if scrollView == drawerScrollView
        {
            // Find the closest anchor point and snap there.
            var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
            var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
            
            if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
            {
                collapsedHeight = drawerVCCompliant.collapsedDrawerHeight()
                partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight()
            }
					
					var drawerStops: [CGFloat] = [CGFloat]()
					
					if supportedDrawerPositions.contains(.Open)
					{
							drawerStops.append((self.view.bounds.size.height - topInset))
					}

					if supportedDrawerPositions.contains(.PartiallyRevealed)
					{
							drawerStops.append(partialRevealHeight)
					}

					if supportedDrawerPositions.contains(.Collapsed)
					{
							drawerStops.append(collapsedHeight)
					}

					let lowestStop = drawerStops.minElement() ?? 0
            
            let distanceFromBottomOfView = lowestStop + lastDragTargetContentOffset.y
            
            var currentClosestStop = lowestStop
            
            for currentStop in drawerStops
            {
                if abs(currentStop - distanceFromBottomOfView) < abs(currentClosestStop - distanceFromBottomOfView)
                {
                    currentClosestStop = currentStop
                }
            }
            
            if abs(Float(currentClosestStop - (self.view.bounds.size.height - topInset))) <= FLT_EPSILON && supportedDrawerPositions.contains(.Open)
            {
                setDrawerPosition(.Open, animated: true)
            } else if abs(Float(currentClosestStop - collapsedHeight)) <= FLT_EPSILON && supportedDrawerPositions.contains(.Collapsed)
            {
                setDrawerPosition(.Collapsed, animated: true)
            } else if supportedDrawerPositions.contains(.PartiallyRevealed) {
                setDrawerPosition(.PartiallyRevealed, animated: true)
            }
        }
    }
    
    public func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        if scrollView == drawerScrollView
        {
            lastDragTargetContentOffset = targetContentOffset.memory
            
            // Halt intertia
            targetContentOffset.memory = scrollView.contentOffset
        }
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        
        if scrollView == drawerScrollView
        {
            var partialRevealHeight:CGFloat = kPulleyDefaultPartialRevealHeight
            var collapsedHeight:CGFloat = kPulleyDefaultCollapsedHeight
            
            if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate
            {
                collapsedHeight = drawerVCCompliant.collapsedDrawerHeight()
                partialRevealHeight = drawerVCCompliant.partialRevealDrawerHeight()
            }
					
					var drawerStops: [CGFloat] = [CGFloat]()
					
					if supportedDrawerPositions.contains(.Open) || true
					{
							drawerStops.append((self.view.bounds.size.height - topInset))
					}

					if supportedDrawerPositions.contains(.PartiallyRevealed) || true
					{
							drawerStops.append(partialRevealHeight)
					}

					if supportedDrawerPositions.contains(.Collapsed) || true
					{
							drawerStops.append(collapsedHeight)
					}

					let lowestStop = drawerStops.minElement() ?? 0
            
            if scrollView.contentOffset.y > partialRevealHeight - lowestStop
            {
                // Calculate percentage between partial and full reveal
                let fullRevealHeight = (self.view.bounds.size.height - topInset)
                
                let progress = (scrollView.contentOffset.y - (partialRevealHeight - lowestStop)) / (fullRevealHeight - (partialRevealHeight))
                
                delegate?.makeUIAdjustmentsForFullscreen?(progress)
                (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress)
                (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(progress)
                
                backgroundDimmingView.alpha = progress * backgroundDimmingOpacity
                
                backgroundDimmingView.userInteractionEnabled = true
            }
            else
            {
                if backgroundDimmingView.alpha >= 0.001
                {
                    backgroundDimmingView.alpha = 0.0
                    
                    delegate?.makeUIAdjustmentsForFullscreen?(0.0)
                    (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.makeUIAdjustmentsForFullscreen?(0.0)
                    (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.makeUIAdjustmentsForFullscreen?(0.0)
                    
                    backgroundDimmingView.userInteractionEnabled = false
                }
            }
            
            delegate?.drawerChangedDistanceFromBottom?(self, distance: scrollView.contentOffset.y + lowestStop)
            (drawerContentViewController as? PulleyDrawerViewControllerDelegate)?.drawerChangedDistanceFromBottom?(self, distance: scrollView.contentOffset.y + lowestStop)
            (primaryContentViewController as? PulleyPrimaryContentControllerDelegate)?.drawerChangedDistanceFromBottom?(self, distance: scrollView.contentOffset.y + lowestStop)
        }
    }
    
    // MARK: Touch Passthrough ScrollView Delegate
    
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
        if drawerPosition == .Open
        {
            return backgroundDimmingView
        }
        
        return primaryContentContainer
    }
	
	// MARK: Propogate child view controller style / status bar presentation based on drawer state
 
	
    override public func childViewControllerForStatusBarStyle() -> UIViewController? {
			if drawerPosition == .Open {
					return drawerContentViewController
			}

			return primaryContentViewController
    }
 
    override public func childViewControllerForStatusBarHidden() -> UIViewController? {
			if drawerPosition == .Open {
					return drawerContentViewController
			}

			return primaryContentViewController
    }
}
