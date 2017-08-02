//
//  PulleyViewController+Nested.swift
//  Pulley
//
//  Created by Ethan Gill on 8/1/17.
//

import Foundation

extension PulleyViewController: PulleyDrawerViewControllerDelegate {
    public func collapsedDrawerHeight() -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.collapsedDrawerHeight()
        } else {
            return 68.0
        }
    }

    public func partialRevealDrawerHeight() -> CGFloat {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.partialRevealDrawerHeight()
        } else {
            return 264.0
        }
    }

    public func supportedDrawerPositions() -> [PulleyPosition] {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            return drawerVCCompliant.supportedDrawerPositions()
        } else {
            return PulleyPosition.all
        }
    }

    public func drawerPositionDidChange(drawer: PulleyViewController) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerPositionDidChange?(drawer: drawer)
        }
    }

    public func makeUIAdjustmentsForFullscreen(progress: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.makeUIAdjustmentsForFullscreen?(progress: progress)
        }
    }

    public func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat) {
        if let drawerVCCompliant = drawerContentViewController as? PulleyDrawerViewControllerDelegate {
            drawerVCCompliant.drawerChangedDistanceFromBottom?(drawer: drawer, distance: distance)
        }
    }
}
