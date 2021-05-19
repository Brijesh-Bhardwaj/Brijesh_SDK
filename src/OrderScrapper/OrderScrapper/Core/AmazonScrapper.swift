//  AmazonScrapper.swift
//  OrderScrapper

import Foundation

class AmazonScrapper: BSScrapper {
   
    override func getAuthenticator() throws -> BSAuthenticator {
        if mAuthenticator == nil {
            mAuthenticator = BSAmazonAuthenticator(webClient: mWebClient)
        }
        return mAuthenticator!
    }
      
}
