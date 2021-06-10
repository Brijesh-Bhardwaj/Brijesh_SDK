//  BSDataUploader.swift
//  OrderScrapper

import Foundation

protocol DataUploadListener {
    func onDataUploadComplete()
}
class BSDataUploader {
    let OrderID = "orderId"
    let dateRange: DateRange
    let orderDetail: OrderDetailsMO
    let listener: DataUploadListener
    var orderData = [String: Dictionary<String,Any>]()
    
    init(dateRange: DateRange, orderDetail: OrderDetailsMO, listener: DataUploadListener) {
        self.dateRange = dateRange
        self.orderDetail = orderDetail
        self.listener = listener
    }
    
    func addData(data: Dictionary<String, Any>) {
        if let orderId = data[OrderID] as? String {
            orderData[orderId] = data
            uploadData(data: data)
        }
    }
    
    func uploadData(data: Dictionary<String, Any>) {
        let orderRequest = OrderRequest(panelistId: orderDetail.panelistID, amazonId: orderDetail.userID, fromDate: dateRange.fromDate!, toDate: dateRange.toDate!, data: [data])
        _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest) { [self] response, error in
            if let response = response {
                print("### uploadData() Response ", response)
                let orderIds = response.orderData
                if !orderIds.isEmpty {
                    for orderId in orderIds {
                        let removeOrderId = orderId.orderId
                        self.removeDataFromArray(orderId: removeOrderId)
                        
                        //Delete order details from DB
                        CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: removeOrderId, orderSource: orderDetail.orderSource)
                    }
                }
            } else {
                print("### uploadData() Error ")
                let orderId = data[OrderID]
                self.removeDataFromArray(orderId: orderId as! String)
            }
        }
    }
    
    func removeDataFromArray(orderId: String) {
        if !orderData.isEmpty {
            orderData.removeValue(forKey: orderId)
            print("### Remove from the dictionary ", orderId)
        }
    }
}
