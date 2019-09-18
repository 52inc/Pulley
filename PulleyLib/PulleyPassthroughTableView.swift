//
//  PulleyPassthroughTableView.swift
//  Pulley
//
//  Created by Keith Lamprecht on 9/18/19.
//
import UIKit

protocol PulleyPassthroughTableViewDelegate: class {
    
    func shouldTouchPassthroughScrollView(scrollView: PulleyPassthroughTableView, point: CGPoint) -> Bool
    func viewToReceiveTouch(scrollView: PulleyPassthroughTableView, point: CGPoint) -> UIView
}

class PulleyPassthroughTableView: UITableView {
    
    weak var touchDelegate: PulleyPassthroughTableViewDelegate?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        if
            let touchDelegate = touchDelegate,
            touchDelegate.shouldTouchPassthroughScrollView(scrollView: self, point: point)
        {
            return touchDelegate.viewToReceiveTouch(scrollView: self, point: point).hitTest(touchDelegate.viewToReceiveTouch(scrollView: self, point: point).convert(point, from: self), with: event)
        }
        
        return super.hitTest(point, with: event)
    }
}
