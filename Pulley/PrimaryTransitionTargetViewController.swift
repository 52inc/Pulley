//
//  PrimaryTransitionTargetViewController.swift
//  Pulley
//
//  Created by Brendan Lee on 7/8/16.
//  Copyright © 2016 52inc. All rights reserved.
//

import UIKit
import Pulley

class PrimaryTransitionTargetViewController: UIViewController {

    @IBAction func goBackButtonPressed(sender: AnyObject) {
        // Uncomment the bellow code to create a secondary drawer content view controller
        // and set it's initial position with setDrawerContentViewController(controller, position, animated, completion)
        /*
        let drawerContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SecondaryDrawerContentViewController")
        
        self.pulleyViewController?.setDrawerContentViewController(controller: drawerContent, position: .open, animated: true, completion: nil)
        */
        
        let primaryContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryContentViewController")

        self.pulleyViewController?.setPrimaryContentViewController(controller: primaryContent, animated: true)

    }
}
