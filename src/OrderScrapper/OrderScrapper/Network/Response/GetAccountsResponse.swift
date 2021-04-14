//
//  GetAccountsResponse.swift
//  OrderScrapper
//
//  Created by Avinash on 14/04/21.
//

import Foundation

struct GetAccountsResponse: Decodable {
    let hasDisconnectedAccounts: Bool
    let accounts: [AccountDetails]?
}
