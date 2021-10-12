//
//  AmazonService.swift
//  OrderScrapper
//

import Foundation
import Alamofire
import Sentry

private enum JSONKeys: String, CodingKey {
    case panelistId, panelist_id, amazonId, file, fromDate, toDate, status, message, orderStatus, data, configDetails, platformId
}

class AmazonService {
    private static let DateRangeURL = "date-range"
    private static let UploadReportURL = "order_history/upload_order_history"
    private static let PIIListURL = "pii/deactive_pii_list"
    private static let GetAccounts = "amazon-connection/get_accounts"
    private static let CreateConnection = "amazon-connection/register_connection"
    private static let UpdateStatus = "amazon-connection/update_status"
    private static let FetchScript = "scrapping/fetchScript"
    private static let ScrapperConfigURL = "scraper_config/get_config"
    private static let orderUpload = "order_history/upload_orders"
    private static let GetConfigs = "scraper_config"
    private static let PostEvents = "scrapping/push_events"
    
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
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReponseDateRange))
                } else {
                    FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_daterange_api_success")
                    completionHandler(response.data, nil)
                }
            } else {
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_daterange_api_fail")
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
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReposneUplodFile))
                } else {
                    FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_uploadfile_api_success")
                    completionHandler(response.data, nil)
                }
            } else {
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_uploadfile_api_fail")
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
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReposnePIIList))
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
                    FirebaseAnalyticsUtil.logSentryError(error:  APIError(error: response.error ?? Strings.ErrorAPIReposneGetAccount))
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
                    FirebaseAnalyticsUtil.logSentryError(error:  APIError(error: response.error ?? Strings.ErrorAPIReposneRegisterConnection))
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
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIResponseUpdateStatus))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        return client
    }
    
   static func getScrapperConfig(orderSource: [String], completionHandler: @escaping (ScrapeConfigs?, Error?) -> Void) -> APIClient {
        
        let client = NetworkClient<APIResponse<ScrapeConfigs>>(relativeURL: ScrapperConfigURL, requestMethod: .post)
        client.body = [JSONKeys.configDetails.rawValue: orderSource]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<ScrapeConfigs> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "getScrapperConfig", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        return client
    }
    
    static func fetchScript(orderSource: OrderSource, completionHandler: @escaping (FetchScript?, Error?) -> Void) -> APIClient {
        let relativeUrl = FetchScript + "/" + orderSource.value
        let client = NetworkClient<APIResponse<FetchScript>>(relativeURL: relativeUrl, requestMethod: .get)
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<FetchScript> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "fetchScript", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        return client
    }
    
   static func uploadOrderHistory(orderRequest: OrderRequest, completionHandler:
                                    @escaping (OrderData?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<OrderData>>(relativeURL: orderUpload, requestMethod: .post)
        client.body = orderRequest.toDictionary()
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<OrderData> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "uploadOrderHistory error",response.error ?? "Error")
                } else {
                    completionHandler(response.data!, nil)
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
    
    static func logEvents(eventLogs: EventLogs, completionHandler: @escaping (EventLogs?, Error?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<EventLogs>>(relativeURL: PostEvents, requestMethod: .post)
        client.body = eventLogs.toDictionary()
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<EventLogs> {
                if response.isError {
                    completionHandler(nil, APIError(error: response.error ?? "Error"))
                    print(AppConstants.tag, "pushEvents", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
        return client
    }
    
    static func cancelAPI() {
        AF.cancelAllRequests()
    }
}
