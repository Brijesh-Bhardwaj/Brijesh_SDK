//
//  KrogerScrapper.swift
//  OrderScrapper
//
//  Created by admin on 23/09/21.
//

import Foundation

class KrogerScrapper: BSScrapper {
    
    override func getAuthenticator() throws -> BSAuthenticator {
        return BSKrogerAuthenticator(webClient: webClient, delegate: webClientDelegate)
    }
    
    override func getOrderSource() throws -> OrderSource {
        return .Kroger
    }
}
