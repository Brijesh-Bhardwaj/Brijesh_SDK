//  BSDataUploader.swift
//  OrderScrapper

import Foundation

protocol DataUploadListener {
    func onDataUploadComplete()
}
class BSDataUploader {
    private let OrderID = "orderId"
    private let dateRange: DateRange
    private let listener: DataUploadListener
    private var orderData = [String: Dictionary<String,Any>]()
    private let panelistId: String
    private let userId: String
    private let orderSource: String
    
    init(dateRange: DateRange, orderDetail: OrderDetailsMO, listener: DataUploadListener) {
        self.dateRange = dateRange
        self.listener = listener
        self.panelistId = String(orderDetail.panelistID)
        self.userId = String(orderDetail.userID)
        self.orderSource = String(orderDetail.orderSource)
    }
    
    func addData(data: Dictionary<String, Any>) {
        if let orderId = data[OrderID] as? String {
            orderData[orderId] = data
            uploadData(data: data)
        }
    }
    
    func hasDataForUpload() -> Bool {
        return !orderData.isEmpty
    }
    
    func uploadData(data: Dictionary<String, Any>) {
        let orderRequest = OrderRequest(panelistId: self.panelistId, amazonId: self.userId, fromDate: dateRange.fromDate!, toDate: dateRange.toDate!, data: [data])
        _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest) { [self] response, error in
            if let response = response {
                print("### uploadData() Response ", response)
                let orderData = response.orderData
                if let orderIds = orderData, !orderIds.isEmpty {
                    for orderId in orderIds {
                        let removeOrderId = orderId.orderId
                        self.removeDataFromArray(orderId: removeOrderId)
                        
                        //Delete order details from DB
                        CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: removeOrderId, orderSource: self.orderSource)
                    }
                } else {
                    if let orderId = data[OrderID] as? String {
                        self.removeDataFromArray(orderId: orderId)
                        
                        //Delete order details from DB
                        CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: orderId, orderSource: self.orderSource)
                    }
                }
            } else {
                print("### uploadData() Error ")
                let orderId = data[OrderID]
                self.removeDataFromArray(orderId: orderId as! String)
            }
            self.listener.onDataUploadComplete()
        }
    }
    
    func removeDataFromArray(orderId: String) {
        if !orderData.isEmpty {
            orderData.removeValue(forKey: orderId)
            print("### Remove from the dictionary ", orderId)
        }
    }
}
