//
//  UIView+constrainToParent.swift
//  Pulley
//
//  Created by Mathew Polzin on 8/22/17.
//

import UIKit

extension UIView {
    
    internal func constrainToParent() {
        guard let parent = superview else { return }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        parent.addConstraints(["H:|[view]|", "V:|[view]|"].flatMap({ constraintString in
            NSLayoutConstraint.constraints(withVisualFormat: constraintString, options: [], metrics: nil, views: ["view": self])
        }))
    }
}
