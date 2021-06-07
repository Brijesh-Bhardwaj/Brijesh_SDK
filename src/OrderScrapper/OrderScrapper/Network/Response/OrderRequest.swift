//  OrderRequest.swift
//  OrderScrapper


import Foundation

enum OrderJsonKey: String {
    case panelistID, toDate, fromDate, amazonID, data
}

struct OrderRequest {
    let panelistId: String
    let amazonId: String
    let fromDate: String
    let toDate: String
    let data: [[String:Any]]
    
    func toDictionary() -> [String: Any] {
        return [OrderJsonKey.panelistID.rawValue: panelistId, OrderJsonKey.amazonID.rawValue: amazonId, OrderJsonKey.toDate.rawValue: toDate, OrderJsonKey.fromDate.rawValue: fromDate, OrderJsonKey.data.rawValue: data]
    }
}
