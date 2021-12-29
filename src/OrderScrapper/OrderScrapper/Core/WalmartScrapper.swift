//  WalmartScrapper.swift
//  OrderScrapper

import Foundation

class WalmartScrapper: BSScrapper {
    
    override func getAuthenticator() throws -> BSAuthenticator {
        return BSWalmartAuthenticator(webClient: webClient, delegate: webClientDelegate, scraperListener: nil)
    }
    
    override func getOrderSource() throws -> OrderSource {
        return .Walmart
    }
}
