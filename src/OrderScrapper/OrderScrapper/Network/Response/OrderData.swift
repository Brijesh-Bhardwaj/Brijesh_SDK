//  OrderData.swift
//  OrderScrapper


import Foundation

struct OrderData: Decodable {
    let amazonId: String
    let panelistId: String
    let orderData: [OrderId]
}

struct OrderId: Decodable {
    let orderId: String
}
