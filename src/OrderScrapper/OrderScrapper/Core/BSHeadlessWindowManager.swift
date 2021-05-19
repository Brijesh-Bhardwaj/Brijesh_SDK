//  BSHeadlessWindowManager.swift
//  OrderScrapper

import Foundation
import WebKit

class BSHeadlessWindowManager {

    func attachHeadlessView(view: UIView) {
        UIApplication.shared.windows.first?.addSubview(view)
    }
    
    func detachHeadlessView(view: UIView) {
        view.removeFromSuperview()
    }
}
