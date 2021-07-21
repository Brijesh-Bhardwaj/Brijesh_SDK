//  AmazonScrapper.swift
//  OrderScrapper

import Foundation

class AmazonScrapper: BSScrapper {
   
    override func getAuthenticator() throws -> BSAuthenticator {
        return BSAmazonAuthenticator(webClient: webClient, delegate: webClientDelegate)
    }
 
    override func getOrderSource() throws -> OrderSource {
        return .Amazon
    }
}
