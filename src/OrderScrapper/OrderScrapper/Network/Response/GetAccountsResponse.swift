//
//  GetAccountsResponse.swift
//  OrderScrapper

import Foundation

struct GetAccountsResponse: Codable {
    let hasNeverConnected: Bool
    let accounts: [AccountDetails]?
}
