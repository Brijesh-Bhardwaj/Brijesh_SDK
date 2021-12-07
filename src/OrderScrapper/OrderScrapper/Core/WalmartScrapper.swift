//  WalmartScrapper.swift
//  OrderScrapper

import Foundation

class WalmartScrapper: BSScrapper {
    
    override func getAuthenticator() throws -> BSAuthenticator {
        return BSWalmartAuthenticator(webClient: webClient, delegate: webClientDelegate)
    }
    
    override func getOrderSource() throws -> OrderSource {
        return .Walmart
    }
}
