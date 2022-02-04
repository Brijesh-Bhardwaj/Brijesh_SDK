//
//  ReportUpload.swift
//  OrderScrapper
//

import Foundation

struct ReportUpload: Codable {
    let id: Int?
    let fromDate: String?
    let platformId: String?
    let toDate: String?
    let panelistId: String?
    let fileName: String?
    let filePath: String?
    let storageType: String?
    let scrapeTime: String?
}
