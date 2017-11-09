//
//  UIView+constrainToParent.swift
//  Pulley
//
//  Created by Mathew Polzin on 8/22/17.
//

import UIKit

extension UIView {
    
    internal func constrainToParent() {
        constrainToParent(insets: UIEdgeInsets.zero)
    }

    internal func constrainToParent(insets: UIEdgeInsets) {
        guard let parent = superview else { return }

        translatesAutoresizingMaskIntoConstraints = false
        let metrics: [String : Any] = ["left" : insets.left, "right" : insets.right, "top" : insets.top, "bottom" : insets.bottom]

        parent.addConstraints(["H:|-(left)-[view]-(right)-|", "V:|-(top)-[view]-(bottom)-|"].flatMap({ constraintString in
            NSLayoutConstraint.constraints(withVisualFormat: constraintString, options: [], metrics: metrics, views: ["view": self])
        }))
    }
}
