//  OrderRequest.swift
//  OrderScrapper


import Foundation

enum OrderJsonKey: String {
    case panelistId, toDate, fromDate, platformId, data, status
}

struct OrderRequest {
    let panelistId: String
    let platformId: String
    let fromDate: String
    let toDate: String
    let status: String
    let data: [[String:Any]]?
    
    func toDictionary() -> [String: Any] {
        return [OrderJsonKey.panelistId.rawValue: panelistId.lowercased(), OrderJsonKey.platformId.rawValue: platformId.lowercased(), OrderJsonKey.toDate.rawValue: toDate, OrderJsonKey.fromDate.rawValue: fromDate, OrderJsonKey.data.rawValue: data, OrderJsonKey.status.rawValue: status]
    }
}
