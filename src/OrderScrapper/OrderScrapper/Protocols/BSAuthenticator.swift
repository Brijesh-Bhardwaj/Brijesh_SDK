//  BSAuthenticator.swift
//  OrderScrapper


import Foundation

protocol BSAuthenticator {
    func authenticate(account: Account,configurations: Configurations)
}
