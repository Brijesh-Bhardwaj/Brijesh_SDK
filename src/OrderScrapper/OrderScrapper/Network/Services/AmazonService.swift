//
//  AmazonService.swift
//  OrderScrapper
//

import Foundation
import Alamofire

private enum JSONKeys: String, CodingKey {
    case panelistId, panelist_id, amazonId, file, fromDate, toDate
}

class AmazonService {
    private static let DateRangeURL = "date-range"
    private static let UploadReportURL = "order_history/upload_order_history"
    private static let PIIListURL = "pii/deactive_pii_list"
    
    static func getDateRange(amazonId: String,
                             completionHandler: @escaping (DateRange?, APIError?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<DateRange>>(relativeURL: DateRangeURL, requestMethod: .post)
        let panelistId = LibContext.sharedInstance.panelistID
        
        client.body = [JSONKeys.panelistId.rawValue: panelistId, JSONKeys.amazonId.rawValue: amazonId]
        client.headers = [JSONKeys.panelist_id.rawValue: panelistId]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<DateRange> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.message ?? "Error"))
                } else {
                    let testDateRange = DateRange(fromDate: "05-01-2014", toDate: "19-03-2019")
                    completionHandler(testDateRange, nil)
                }
            } else {
               completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func uploadFile(fileURL: URL, amazonId: String,
                           fromDate: String, toDate: String,
                           _ completionHandler: @escaping (ReportUpload?, APIError?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<ReportUpload>>(relativeURL: UploadReportURL, requestMethod: .multipart)
        
        client.headers = [JSONKeys.panelist_id.rawValue: LibContext.sharedInstance.panelistID]
        client.multipartFormClosure = { multipartData in
            multipartData.append(fileURL, withName: JSONKeys.file.rawValue)
            multipartData.append(Data(amazonId.utf8), withName: JSONKeys.amazonId.rawValue)
            multipartData.append(Data(LibContext.sharedInstance.panelistID.utf8), withName: JSONKeys.panelistId.rawValue)
            multipartData.append(Data(fromDate.utf8), withName: JSONKeys.fromDate.rawValue)
            multipartData.append(Data(toDate.utf8), withName: JSONKeys.toDate.rawValue)
        }
        
        client.executeAPI() { response, error in
            if let response = response as? APIResponse<ReportUpload> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.message ?? "Error"))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
               completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func getPIIList(completionHandler: @escaping ([PIIAttribute]?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<[PIIAttribute]>>(relativeURL: PIIListURL, requestMethod: .get)
        
        client.headers = [JSONKeys.panelist_id.rawValue: LibContext.sharedInstance.panelistID]
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<[PIIAttribute]> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.message ?? "Error"))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
               completionHandler(nil, nil)
            }
        }
        
        return client
    }
}
