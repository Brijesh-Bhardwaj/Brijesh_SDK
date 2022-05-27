//  OrderRequest.swift
//  OrderScrapper


import Foundation

enum OrderJsonKey: String {
    case panelistId, toDate, fromDate, platformId, data, status, listingScrapeTime, listingOrderCount, scrapingSessionContext, scrapingSessionStatus, scrapingSessionStartedAt,scrapingSessionEndedAt,sessionId
}

struct OrderRequest {
    let panelistId: String
    let platformId: String
    let fromDate: String
    let toDate: String
    let status: String
    let data: [[String:Any]]?
    let listingScrapeTime: Int64?
    let listingOrderCount: Int?
    let scrapingSessionContext: String?
    let scrapingSessionStatus: String?
    let scrapingSessionStartedAt: String?
    let scrapingSessionEndedAt: String?
    let sessionId: String?
    
    func toDictionary() -> [String: Any] {
        return [OrderJsonKey.panelistId.rawValue: panelistId.lowercased(), OrderJsonKey.platformId.rawValue: platformId.lowercased(), OrderJsonKey.toDate.rawValue: toDate, OrderJsonKey.fromDate.rawValue: fromDate, OrderJsonKey.data.rawValue: data, OrderJsonKey.status.rawValue: status, OrderJsonKey.listingScrapeTime.rawValue: listingScrapeTime, OrderJsonKey.listingOrderCount.rawValue: listingOrderCount, OrderJsonKey.scrapingSessionStatus.rawValue: scrapingSessionStatus,OrderJsonKey.scrapingSessionContext.rawValue: scrapingSessionContext?.lowercased(),
            OrderJsonKey.scrapingSessionStartedAt.rawValue: scrapingSessionStartedAt,OrderJsonKey.scrapingSessionEndedAt.rawValue: scrapingSessionEndedAt,OrderJsonKey.sessionId.rawValue: sessionId]
    }
}
