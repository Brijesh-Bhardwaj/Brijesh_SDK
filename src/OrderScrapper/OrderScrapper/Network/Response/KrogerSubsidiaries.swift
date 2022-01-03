//
//  KrogerSubsidiaries.swift
//  OrderScrapper

import Foundation
struct KrogerSubsidiaries: Codable {
    let htmlResponse: String?
    
    enum CodingKeys : String, CodingKey {
            case htmlResponse = "HTMLResponse"
        }
}

