//
//  LibContext.swift
//  OrderScrapper
//

import Foundation

class LibContext {
    public static let sharedInstance = LibContext()
    private init() {
        
    }
    var panelistID = ""
    var authToken = ""
}
