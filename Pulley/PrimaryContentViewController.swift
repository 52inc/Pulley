//
//  ViewController.swift
//  Pulley
//
//  Created by Brendan Lee on 7/6/16.
//  Copyright © 2016 52inc. All rights reserved.
//

import UIKit
import MapKit
import Pulley

class PrimaryContentViewController: UIViewController {
    
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var controlsContainer: UIView!
    @IBOutlet var temperatureLabel: UILabel!
    
    /**
     * IMPORTANT! If you have constraints that you use to 'follow' the drawer (like the temperature label in the demo)...
     * Make sure you constraint them to the bottom of the superview and NOT the superview's bottom margin. Double click the constraint, and you can change it in the dropdown in the right-side panel. If you don't, you'll have varying spacings to the drawer depending on the device.
     */
    @IBOutlet var temperatureLabelBottomConstraint: NSLayoutConstraint!
    
    fileprivate let temperatureLabelBottomDistance: CGFloat = 8.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        controlsContainer.layer.cornerRadius = 10.0
        temperatureLabel.layer.cornerRadius = 7.0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Customize Pulley in viewWillAppear, as the view controller's viewDidLoad will run *before* Pulley's and some changes may be overwritten.
        // Uncomment if you want to change the visual effect style to dark. Note: The rest of the sample app's UI isn't made for dark theme. This just shows you how to do it.
        // drawer.drawerBackgroundVisualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

        // We want the 'side panel' layout in landscape iPhone / iPad, so we set this to 'automatic'. The default is 'bottomDrawer' for compatibility with older Pulley versions.
        self.pulleyViewController?.displayMode = .automatic
    }
    
    @IBAction func runPrimaryContentTransitionWithoutAnimation(sender: AnyObject) {
        let primaryContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryTransitionTargetViewController")

        self.pulleyViewController?.setPrimaryContentViewController(controller: primaryContent, animated: false)
    }
    
    @IBAction func runPrimaryContentTransition(sender: AnyObject) {
        let primaryContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryTransitionTargetViewController")

        self.pulleyViewController?.setPrimaryContentViewController(controller: primaryContent, animated: true)
    }
}

extension PrimaryContentViewController: PulleyPrimaryContentControllerDelegate {
    
    func makeUIAdjustmentsForFullscreen(progress: CGFloat, bottomSafeArea: CGFloat)
    {
        guard let drawer = self.pulleyViewController, drawer.currentDisplayMode == .bottomDrawer else {
            controlsContainer.alpha = 1.0
            return
        }
        
        controlsContainer.alpha = 1.0 - progress
    }
    
    func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat)
    {
        guard drawer.currentDisplayMode == .bottomDrawer else {
            
            temperatureLabelBottomConstraint.constant = temperatureLabelBottomDistance
            return
        }
        
        if distance <= 268.0 + bottomSafeArea
        {
            temperatureLabelBottomConstraint.constant = distance + temperatureLabelBottomDistance
        }
        else
        {
            temperatureLabelBottomConstraint.constant = 268.0 + temperatureLabelBottomDistance
        }
    }
}

