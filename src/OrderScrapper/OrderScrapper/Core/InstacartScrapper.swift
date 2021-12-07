//  InstacartScrapper.swift
//  OrderScrapper
//


import Foundation

class InstacartScrapper: BSScrapper {
    
    override func getAuthenticator() throws -> BSAuthenticator {
        return BSInstacartAuthenticator(webClient: webClient, delegate: webClientDelegate)
    }
 
    override func getOrderSource() throws -> OrderSource {
        return .Instacart
    }
}
