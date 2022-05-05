//  AmazonLogValues.swift
//  OrderScrapper

import Foundation

enum EventJsonKey: String {
    case panelistId, toDate, fromDate, platformId, section, status, message, type, scrappingType, scrapingContext, deviceId, devicePlatform,url
}

struct EventLogs: Codable {
    let panelistId: String
    let platformId: String?
    let section: String
    let type: String
    let status: String
    let message: String
    let fromDate: String?
    let toDate: String?
    let scrapingType: String?
    let scrapingContext: String?
    let url: String?
    
    
    
    func toDictionary() -> [String: Any] {
        return [EventJsonKey.panelistId.rawValue: panelistId.lowercased(), EventJsonKey.section.rawValue: section, EventJsonKey.toDate.rawValue: toDate as Any, EventJsonKey.fromDate.rawValue: fromDate as Any, EventJsonKey.status.rawValue: status,EventJsonKey.message.rawValue: message, EventJsonKey.type.rawValue: type, EventJsonKey.platformId.rawValue: platformId?.lowercased(), EventJsonKey.scrappingType.rawValue: scrapingType as Any, EventJsonKey.scrapingContext.rawValue: scrapingContext?.lowercased() as Any, EventJsonKey.deviceId.rawValue: AppConstants.deviceId, EventJsonKey.devicePlatform.rawValue: AppConstants.devicePlatform,EventJsonKey.url.rawValue: url]
    }
}


