//
//  NavigationHelper.swift
//  OrderScrapper
//

import Foundation

protocol NavigationHelper {
    func navigateWith(url: URL?)
    
    func shouldIntercept(navigationResponse: URLResponse) -> Bool
    
    func intercept(navigationResponse: URLResponse, cookies: [HTTPCookie])
}
