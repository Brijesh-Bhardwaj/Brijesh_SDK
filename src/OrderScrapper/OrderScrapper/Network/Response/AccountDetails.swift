import Foundation
//  AccountDetails.swift
//  OrderScrapper

struct AccountDetails: Codable {
    let id: Int
    let panelistId: String
    let amazonId: String
    let status: String
    let message: String
    let firstaccount: Bool
}
