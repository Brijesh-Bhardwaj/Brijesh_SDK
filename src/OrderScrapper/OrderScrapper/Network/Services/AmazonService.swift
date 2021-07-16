//
//  AmazonService.swift
//  OrderScrapper
//

import Foundation
import Alamofire
import Sentry

private enum JSONKeys: String, CodingKey {
    case panelistId, panelist_id, amazonId, file, fromDate, toDate, status, message, orderStatus
}

class AmazonService {
    private static let DateRangeURL = "date-range"
    private static let UploadReportURL = "order_history/upload_order_history"
    private static let PIIListURL = "pii/deactive_pii_list"
    private static let GetAccounts = "amazon-connection/get_accounts"
    private static let CreateConnection = "amazon-connection/register_connection"
    private static let UpdateStatus = "amazon-connection/update_status"
    private static let GetConfigs = "scraper_config"
    
    static func getDateRange(amazonId: String,
                             completionHandler: @escaping (DateRange?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<DateRange>>(relativeURL: DateRangeURL, requestMethod: .post)
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.panelistId.rawValue: panelistId, JSONKeys.amazonId.rawValue: amazonId]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<DateRange> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "getDateRange", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIReponseDateRange))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func uploadFile(fileURL: URL, amazonId: String,
                           fromDate: String, toDate: String,
                           _ completionHandler: @escaping (ReportUpload?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<ReportUpload>>(relativeURL: UploadReportURL, requestMethod: .multipart)
        
        let panelistId = LibContext.shared.authProvider.getPanelistID()
    
        client.multipartFormClosure = { multipartData in
            multipartData.append(fileURL, withName: JSONKeys.file.rawValue)
            multipartData.append(Data(amazonId.utf8), withName: JSONKeys.amazonId.rawValue)
            multipartData.append(Data(panelistId.utf8), withName: JSONKeys.panelistId.rawValue)
            multipartData.append(Data(fromDate.utf8), withName: JSONKeys.fromDate.rawValue)
            multipartData.append(Data(toDate.utf8), withName: JSONKeys.toDate.rawValue)
        }
        
        client.executeAPI() { response, error in
            if let response = response as? APIResponse<ReportUpload> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "uploadFile", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIReposneUplodFile))
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
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<[PIIAttribute]> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "getPIIList", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIReposnePIIList))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func getAccounts(completionHandler: @escaping (GetAccountsResponse?, Error?) -> Void) -> APIClient {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let relativeUrl = GetAccounts + "/" + panelistId
        let client = NetworkClient<APIResponse<GetAccountsResponse>>(relativeURL: relativeUrl, requestMethod: .get)
       
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<GetAccountsResponse> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "getAccounts", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIReposneGetAccount))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func registerConnection(amazonId: String, status: String, message: String, orderStatus: String, completionHandler: @escaping (AccountDetails?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<AccountDetails>>(relativeURL: CreateConnection, requestMethod: .post)
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.panelistId.rawValue: panelistId, JSONKeys.amazonId.rawValue: amazonId,
                       JSONKeys.status.rawValue: status, JSONKeys.message.rawValue: message, JSONKeys.orderStatus.rawValue: orderStatus]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<AccountDetails> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "registerConnection", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIReposneRegisterConnection))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        
        return client
    }
    
    static func updateStatus(amazonId: String, status: String, message: String, orderStatus: String,
                                 completionHandler: @escaping (AccountDetails?, Error?) -> Void) -> APIClient {
        let relativeUrl = UpdateStatus
        let client = NetworkClient<APIResponse<AccountDetails>>(relativeURL: relativeUrl, requestMethod: .put)
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.status.rawValue: status, JSONKeys.message.rawValue: message, JSONKeys.orderStatus.rawValue: orderStatus,JSONKeys.amazonId.rawValue: amazonId, JSONKeys.panelistId.rawValue: panelistId]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<AccountDetails> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "updateStatus", response.error ?? "Error")
                    SentrySDK.capture(error: APIError(error: response.error ?? Strings.ErrorAPIResponseUpdateStatus))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        return client
    }
    
    static func getConfigs(completionHandler: @escaping (Configs?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<Configs>>(relativeURL: GetConfigs, requestMethod: .get)
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<Configs> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "getConfigs", response.error ?? "Error")
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
