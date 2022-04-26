//  BSAuthenticator.swift
//  OrderScrapper


import Foundation

protocol BSAuthenticator {
    func authenticate(account: Account,
                      configurations: Configurations,
                      scrapingMode: String?,
                      completionHandler: @escaping ((Bool, ASLException?) -> Void))
}
