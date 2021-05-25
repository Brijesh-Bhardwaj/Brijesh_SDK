//  AmazonScrapper.swift
//  OrderScrapper

import Foundation

class AmazonScrapper: BSScrapper {
   
    override func getAuthenticator() throws -> BSAuthenticator {
        if authenticator == nil {
            authenticator = BSAmazonAuthenticator(webClient: webClient, delegate: webClientDelegate, listener: self)
        }
        return authenticator!
    }
 
    override func getOrderSource() throws -> OrderSource {
        return .Amazon
    }
}
