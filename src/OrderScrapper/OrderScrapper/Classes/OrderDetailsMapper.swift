//
//  OrderDetailsMapper.swift
//  OrderScrapper
//
//  Created by Avinash on 12/06/21.
//

import Foundation

class OrderDetailsMapper {
    private init() {}
    
    public static func mapFromDBObject(dbOrderDetails: [OrderDetailsMO]) -> [OrderDetails] {
        var orderDetails: [OrderDetails] = []
        if !dbOrderDetails.isEmpty {
            for dbOrderDetail in dbOrderDetails {
                let orderDate = DateUtils.getDateStringFrom(date: dbOrderDetail.orderDate)
                let orderDetail = OrderDetails(orderID: dbOrderDetail.orderID, orderDate: orderDate, orderSource: dbOrderDetail.orderSource, userID: dbOrderDetail.userID, panelistID: dbOrderDetail.panelistID, orderDeatilsURL: dbOrderDetail.orderDetailsURL)
                orderDetails.append(orderDetail)
            }
        }
        return orderDetails
    }
}
