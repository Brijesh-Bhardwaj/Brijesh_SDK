//
//  GradientView.swift
//  OrderScrapper
//

import Foundation
import UIKit

@IBDesignable
class RadialGradientView: UIView {
    @IBInspectable var outsideColor: UIColor = UIColor.red
    @IBInspectable var insideColor: UIColor = UIColor.green

    override func draw(_ rect: CGRect) {
        let colors = [insideColor.cgColor, outsideColor.cgColor] as CFArray
        let endRadius = sqrt(pow(frame.width/2, 2) + pow(frame.height/2, 2))
        let center = CGPoint(x: bounds.size.width / 2, y: bounds.size.height / 2)
        let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: nil)
        let context = UIGraphicsGetCurrentContext()

        context?.drawRadialGradient(gradient!, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: endRadius, options: CGGradientDrawingOptions.drawsBeforeStartLocation)
    }
}
