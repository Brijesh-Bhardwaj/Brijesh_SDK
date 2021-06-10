//  BSHeadlessWindowManager.swift
//  OrderScrapper

import Foundation
import WebKit

class BSHeadlessWindowManager {

    func attachHeadlessView(view: UIView) {
        view.isHidden = true
        UIApplication.shared.windows.first?.addSubview(view)
    }
    
    func detachHeadlessView(view: UIView) {
        view.removeFromSuperview()
    }
}
