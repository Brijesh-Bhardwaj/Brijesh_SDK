//
//  HorizontalProgressBar.swift
//  OrderScrapper
//

import UIKit

@IBDesignable
class HorizontalProgressBar: UIView {
    @IBInspectable var color: UIColor? = .gray
    
    var progress: CGFloat = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        let backgroundMask = CAShapeLayer()
        backgroundMask.path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.25).cgPath
        layer.mask = backgroundMask
        
        let progressRect = CGRect(origin: .zero, size: CGSize(width: rect.width * progress, height: rect.height))
        let progressLayer = CALayer()
        progressLayer.frame = progressRect
        
        layer.addSublayer(progressLayer)
        progressLayer.backgroundColor = color?.cgColor
    }
}
