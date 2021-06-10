//  OrderRequest.swift
//  OrderScrapper


import Foundation

enum OrderJsonKey: String {
    case panelistId, toDate, fromDate, amazonId, data
}

struct OrderRequest {
    let panelistId: String
    let amazonId: String
    let fromDate: String
    let toDate: String
    let data: [[String:Any]]?
    
    func toDictionary() -> [String: Any] {
        return [OrderJsonKey.panelistId.rawValue: panelistId, OrderJsonKey.amazonId.rawValue: amazonId, OrderJsonKey.toDate.rawValue: toDate, OrderJsonKey.fromDate.rawValue: fromDate, OrderJsonKey.data.rawValue: data]
    }
}
