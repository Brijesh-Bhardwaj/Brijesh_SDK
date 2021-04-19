//
//  GetAccountsResponse.swift
//  OrderScrapper

import Foundation

struct GetAccountsResponse: Decodable {
    let hasNeverConnected: Bool
    let accounts: [AccountDetails]?
}
