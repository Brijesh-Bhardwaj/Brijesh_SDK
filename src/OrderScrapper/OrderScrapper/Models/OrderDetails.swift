//  OrderDetails.swift
//  OrderScrapper

import Foundation

public class OrderDetails: Decodable {
    
    var orderId: String
    var orderDate: String
    var detailsUrl: String
    var orderSource: String?
    var userID: String?
    var panelistID: String?
    var date: Date?
    
    init(orderID: String, orderDate: String, orderSource: String, userID: String, panelistID: String,orderDeatilsURL: String) {
        self.orderId = orderID
        self.orderDate = orderDate
        self.orderSource = orderSource
        self.panelistID = panelistID
        self.userID = userID
        self.detailsUrl = orderDeatilsURL
    }
    
}
