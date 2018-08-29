//
//  UIViewController+PulleyViewController.swift
//  Pulley
//
//  Created by Guilherme Souza on 4/28/18.
//  Copyright © 2018 52inc. All rights reserved.
//

public extension UIViewController {

    /// If this viewController pertences to a PulleyViewController, return it.
    public var pulleyViewController: PulleyViewController? {
        var parentVC = parent
        while parentVC != nil {
            if let pulleyViewController = parentVC as? PulleyViewController {
                return pulleyViewController
            }
            parentVC = parentVC?.parent
        }
        return nil
    }
}
