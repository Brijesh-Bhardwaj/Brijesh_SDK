//
//  Authenticator.swift
//  OrderScrapper
//

import Foundation

protocol Authenticator {
    func authenticate()
    
    func isUserAuthenticated() -> Bool
    
    func resetAuthenticatedFlag()
}
