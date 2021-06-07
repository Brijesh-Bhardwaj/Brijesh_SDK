//  BSDataUploader.swift
//  OrderScrapper

import Foundation

protocol DataUploadListener {
    func onDataUploadComplete()
}
class BSDataUploader {
    let dateRange: DateRange
    let orderDetail: OrderDetailsMO
    var orderData:[String] = []
    let listener: DataUploadListener
    
    init(dateRange: DateRange, orderDetail: OrderDetailsMO, listener: DataUploadListener) {
        self.dateRange = dateRange
        self.orderDetail = orderDetail
        self.listener = listener
    }
    
    func addData(data: String) {
        self.orderData.append(data)
        uploadData(data: data)
    }
    
    func uploadData(data: String) {
        let dataDictionary = convertToDictionary(text: data)
        if let dataDictionary = dataDictionary {
            let orderRequest = OrderRequest(panelistId: orderDetail.panelistID, amazonId: orderDetail.userID, fromDate: dateRange.fromDate!, toDate: dateRange.toDate!, data: [dataDictionary])
            
            _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest) { [self] response, error in
                if let response = response {
                    print("### uploadData() Response ", response)
                    
                    self.removeDataFromArray(data: data)
                    
                    //Delete order details from DB
                    CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: orderDetail.orderID, orderSource: orderDetail.orderSource)
                } else {
                    self.removeDataFromArray(data: data)
                }
                
                if !orderData.isEmpty {
                    self.uploadData(data: orderData.first!)
                } else {
                    self.listener.onDataUploadComplete()
                }
            }
        }
    }
    
    func removeDataFromArray(data: String) {
        //Remove from the array
        if !data.isEmpty, data.contains(data) {
            print("### Array contains. ",orderData.count)
            self.orderData = self.orderData.filter() {$0 != data}
            print("### After removing",orderData.count)
        }
    }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
