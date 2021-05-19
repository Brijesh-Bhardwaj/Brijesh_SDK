//  BSAuthenticator.swift
//  OrderScrapper


import Foundation

protocol BSAuthenticator {
    func authenticate(url: String, account: Account, listener: BSAuthenticationStatusListener)
}
