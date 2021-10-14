//
//  NavigationHelper.swift
//  OrderScrapper
//

import Foundation

protocol NavigationHelper {
    var isGenerateReport: Bool { get set }
    
    func navigateWith(url: URL?)
    
    func shouldShowWebViewFor(url: URL?) -> Bool
}
