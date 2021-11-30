//
//  DateRange.swift
//  OrderScrapper
//

import Foundation

struct DateRange: Codable {
    let fromDate: String?
    let toDate: String?
    let enableScraping: Bool
    let lastOrderId: String?
    let scrappingType: String?
    let showNotification: Bool
}
