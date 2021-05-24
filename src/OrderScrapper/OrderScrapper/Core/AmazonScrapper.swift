//  AmazonScrapper.swift
//  OrderScrapper

import Foundation

class AmazonScrapper: BSScrapper {
   
    override func getAuthenticator() throws -> BSAuthenticator {
        if mAuthenticator == nil {
            mAuthenticator = BSAmazonAuthenticator(webClient: mWebClient, listener: self)
        }
        return mAuthenticator!
    }
 
    override func getOrderSource() throws -> OrderSource {
        return .Amazon
    }
    
    
}
