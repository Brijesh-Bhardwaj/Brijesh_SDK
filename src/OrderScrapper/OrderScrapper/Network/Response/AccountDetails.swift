import Foundation
//  AccountDetails.swift
//  OrderScrapper

struct AccountDetails: Codable {
    let id: Int
    let panelistId: String
    let platformId: String
    let status: String
    let message: String
    let firstaccount: Bool
    let showNotification: Bool?
}
