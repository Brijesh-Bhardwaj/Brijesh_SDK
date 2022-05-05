//  OrderDetails.swift
//  OrderScrapper

import Foundation

public class OrderDetails: Codable {
    
    var orderId: String
    var orderDate: String?
    var detailsUrl: String
    var orderSource: String?
    var userID: String?
    var panelistID: String?
    var date: Date?
    var startDate: String?
    var endDate: String?
    var orderSectionType: String?
    var uploadRetryCount: Int16?
    var sessionID: String?

    
    init(orderID: String, orderDate: String?, orderSource: String, userID: String, panelistID: String, orderDeatilsURL: String, startDate: String, endDate: String, orderSectionType: String, uploadRetryCount: Int16,sessionID:String) {
        self.orderId = orderID
        self.orderDate = orderDate
        self.orderSource = orderSource
        self.panelistID = panelistID
        self.userID = userID
        self.detailsUrl = orderDeatilsURL
        self.startDate = startDate
        self.endDate = endDate
        self.orderSectionType = orderSectionType
        self.uploadRetryCount = uploadRetryCount
        self.sessionID = sessionID
    }
    
}
