//  BSAuthenticator.swift
//  OrderScrapper


import Foundation

protocol BSAuthenticator {
    func authenticate(account: Account,
                      configurations: Configurations,
                      completionHandler: @escaping ((Bool, ASLException?) -> Void))
}
