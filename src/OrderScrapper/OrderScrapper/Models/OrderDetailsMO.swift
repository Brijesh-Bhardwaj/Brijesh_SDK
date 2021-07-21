//  OrderDetailsMO.swift
//  OrderScrapper


import Foundation
import CoreData

@objc(OrderDetails)
class OrderDetailsMO: NSManagedObject {
    @NSManaged var orderID: String
    @NSManaged var orderDate: Date?
    @NSManaged var orderSource: String
    @NSManaged var userID: String
    @NSManaged var panelistID: String
    @NSManaged var orderDetailsURL: String
    @NSManaged var startDate: String
    @NSManaged var endDate: String
}
