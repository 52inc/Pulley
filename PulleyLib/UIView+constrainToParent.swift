//
//  UIView+constrainToParent.swift
//  Pulley
//
//  Created by Mathew Polzin on 8/22/17.
//

import UIKit

extension UIView {
    
    func constrainToParent() {
        constrainToParent(insets: .zero)
    }
    
    func constrainToParent(insets: UIEdgeInsets) {
        guard let parent = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false

		topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top).isActive = true
		leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left).isActive = true

		let bc = bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)
		bc.priority = .init(999)
		bc.isActive = true

		let tc = trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right)
		tc.priority = .init(999)
		tc.isActive = true
    }
}
