//
//  NavigationHelper.swift
//  OrderScrapper
//

import Foundation

protocol NavigationHelper {
    func navigationActionForURL(url: URL?) -> NavigationAction
}
