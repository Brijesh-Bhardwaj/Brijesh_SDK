//
//  DateRange.swift
//  OrderScrapper
//

import Foundation

struct DateRange: Decodable {
    let fromDate: String?
    let toDate: String?
    let enableScraping: Bool
}
