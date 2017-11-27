//
//  PulleyViewController+Nested.swift
//  Pulley
//
//  Created by Ethan Gill on 8/1/17.
//

import UIKit

extension PulleyViewController: PulleyDrawerViewControllerDelegate {
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
