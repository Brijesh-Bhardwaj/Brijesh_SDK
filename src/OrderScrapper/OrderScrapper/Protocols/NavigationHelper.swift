//
//  NavigationHelper.swift
//  OrderScrapper
//

import Foundation

protocol NavigationHelper {
    func navigateWith(url: URL?)
    
    func shouldShowWebViewFor(url: URL?) -> Bool
}
