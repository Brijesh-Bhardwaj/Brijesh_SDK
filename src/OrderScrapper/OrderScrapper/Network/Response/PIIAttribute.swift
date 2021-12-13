//
//  PIIAttribute.swift
//  OrderScrapper
//

import Foundation

struct PIIAttribute: Codable {
    let id: Int
    let attributes: String
    let status: Bool
    let regex: String?
}
