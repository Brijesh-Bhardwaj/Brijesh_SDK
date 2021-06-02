//  OrderDetails.swift
//  OrderScrapper


import Foundation

public class OrderDetails {
    var orderID: String
    var orderDate: Date
    var orderSource: String
    var userID: String
    var panelistID: String
    var orderDeatilsURL: String
    
    init(orderID: String, orderDate: Date, orderSource: String, userID: String, panelistID: String,orderDeatilsURL: String) {
        self.orderID = orderID
        self.orderDate = orderDate
        self.orderSource = orderSource
        self.panelistID = panelistID
        self.userID = userID
        self.orderDeatilsURL = orderDeatilsURL
    }
    
}
