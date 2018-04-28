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
        let primaryContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryContentViewController")

        self.pulleyViewController?.setPrimaryContentViewController(controller: primaryContent, animated: true)
    }
}
