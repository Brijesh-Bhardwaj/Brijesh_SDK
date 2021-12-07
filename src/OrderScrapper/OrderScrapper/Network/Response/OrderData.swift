//  OrderData.swift
//  OrderScrapper


import Foundation

struct OrderData: Codable {
    let platformId: String
    let panelistId: String
    let orderData: [OrderId]?
}

struct OrderId: Codable {
    let orderId: String
}
