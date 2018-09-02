//
//  CustomMaskExample.swift
//  Pulley
//
//  Created by Connor Power on 19.08.18.
//  Copyright © 2018 52inc. All rights reserved.
//

import UIKit

struct CustomMaskExample {

    // MARK: - Constants

    private struct Constants {
        static let cornerRadius: CGFloat = 8.0
        static let cutoutDistanceFromEdge: CGFloat = 32.0
        static let cutoutRadius: CGFloat = 8.0
    }

    // MARK: - Functions

    func customMask(for bounds: CGRect) -> UIBezierPath {
        let maxX = bounds.maxX
        let maxY = bounds.maxY

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: maxY))

        // Left hand edge
        path.addLine(to: CGPoint(x: 0, y: Constants.cornerRadius))

        // Top left rounded corner
        path.addArc(withCenter: CGPoint(x: Constants.cornerRadius, y: Constants.cornerRadius),
                    radius: Constants.cornerRadius,
                    startAngle: CGFloat.pi,
                    endAngle: 1.5 * CGFloat.pi,
                    clockwise: true)

        // Top edge left cutout section
        path.addLine(to: CGPoint(x: Constants.cutoutDistanceFromEdge - Constants.cutoutRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: Constants.cutoutDistanceFromEdge, y: 0),
                    radius: Constants.cutoutRadius,
                    startAngle: CGFloat.pi,
                    endAngle: 2.0 * CGFloat.pi,
                    clockwise: false)
        path.addLine(to: CGPoint(x: Constants.cutoutDistanceFromEdge + Constants.cutoutRadius, y: 0))

        // Top edge right cutout section
        path.addLine(to: CGPoint(x: maxX - Constants.cutoutDistanceFromEdge - Constants.cutoutRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: maxX - Constants.cutoutDistanceFromEdge, y: 0),
                    radius: Constants.cutoutRadius,
                    startAngle: CGFloat.pi,
                    endAngle: 2.0 * CGFloat.pi,
                    clockwise: false)
        path.addLine(to: CGPoint(x: maxX - Constants.cutoutDistanceFromEdge + Constants.cutoutRadius, y: 0))
        path.addLine(to: CGPoint(x: maxX - Constants.cornerRadius, y: 0))

        // Top right rounded corner
        path.addArc(withCenter: CGPoint(x: maxX - Constants.cornerRadius, y: Constants.cornerRadius),
                    radius: Constants.cornerRadius,
                    startAngle: 1.5 * CGFloat.pi,
                    endAngle: 2.0 * CGFloat.pi,
                    clockwise: true)

        // Right hand edge
        path.addLine(to: CGPoint(x: maxX, y: maxY))

        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: maxY))
        path.close()
        path.fill()

        return path
    }

}
