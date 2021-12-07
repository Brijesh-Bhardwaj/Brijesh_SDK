//  AmazonLogValues.swift
//  OrderScrapper

import Foundation

enum EventJsonKey: String {
    case panelistId, toDate, fromDate, platformId, section, status, message, type, scrappingType
}

struct EventLogs: Codable {
    let panelistId: String
    let platformId: String
    let section: String
    let type: String
    let status: String
    let message: String
    let fromDate: String?
    let toDate: String?
    let scrappingType: String?
    
    
    func toDictionary() -> [String: Any] {
        return [EventJsonKey.panelistId.rawValue: panelistId.lowercased(), EventJsonKey.section.rawValue: section, EventJsonKey.toDate.rawValue: toDate as Any, EventJsonKey.fromDate.rawValue: fromDate as Any, EventJsonKey.status.rawValue: status,EventJsonKey.message.rawValue: message, EventJsonKey.type.rawValue: type, EventJsonKey.platformId.rawValue: platformId.lowercased(), EventJsonKey.scrappingType.rawValue: scrappingType as Any]
    }
}


