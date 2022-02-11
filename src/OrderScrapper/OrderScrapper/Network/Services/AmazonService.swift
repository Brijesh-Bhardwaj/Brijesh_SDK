//
//  AmazonService.swift
//  OrderScrapper
//

import Foundation
import Alamofire
import Sentry

private enum JSONKeys: String, CodingKey {

    case panelistId, panelist_id, amazonId, file, fromDate, toDate, status, message, orderStatus, data, configDetails, orderSource, platformSources, platformId, forceScrape, scrapeTime
}

class AmazonService {
    private static let DateRangeURL = "date-range"
    private static let UploadReportURL = "order_history/upload_order_history"
    private static let PIIListURL = "pii/deactive_pii_list"
    private static let GetAccounts = "connection/get_accounts"
    private static let GetKrogerSubsidiary = "kroger/subsidiary_list"
    private static let CreateConnection = "connection/register_connection"
    private static let UpdateStatus = "connection/update_status"
    private static let FetchScript = "scrapping/fetchScript"
    private static let ScrapperConfigURL = "scraper_config/get_config"
    private static let orderUpload = "order_history/upload_orders"
    private static let GetConfigs = "scraper_config"
    private static let PostEvents = "scrapping/push_events"
    
    
    static func getDateRange(platformId: String, orderSource: String, forceScrape: Bool,
                             completionHandler: @escaping (DateRange?, ASLException?) -> Void) -> APIClient {
        let relativeURL = DateRangeURL + "/" + orderSource
        let client = NetworkClient<APIResponse<DateRange>>(relativeURL: relativeURL, requestMethod: .post)
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.panelistId.rawValue: panelistId.lowercased(), JSONKeys.platformId.rawValue: platformId.lowercased(),                 JSONKeys.forceScrape.rawValue: forceScrape]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<DateRange> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "getDateRange", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReponseDateRange))
                } else {
                    FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_daterange_api_success")
                    completionHandler(response.data, nil)
                }
            } else {
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_daterange_api_fail")
                completionHandler(nil, error)
            }
        }
        
        return client
    }
    
    static func uploadFile(fileURL: URL, platformId: String,
                           fromDate: String, toDate: String, orderSource: String, scrapeTime: String,
                           _ completionHandler: @escaping (ReportUpload?, ASLException?) -> Void) -> APIClient {
        let relativeURL = UploadReportURL + "/" + orderSource
        let client = NetworkClient<APIResponse<ReportUpload>>(relativeURL: relativeURL, requestMethod: .multipart)
        
        let panelistId = LibContext.shared.authProvider.getPanelistID().lowercased()
        let platformid = platformId.lowercased()
        client.multipartFormClosure = { multipartData in
            multipartData.append(fileURL, withName: JSONKeys.file.rawValue)
            multipartData.append(Data(platformid.utf8), withName: JSONKeys.platformId.rawValue)
            multipartData.append(Data(panelistId.utf8), withName: JSONKeys.panelistId.rawValue)
            multipartData.append(Data(fromDate.utf8), withName: JSONKeys.fromDate.rawValue)
            multipartData.append(Data(toDate.utf8), withName: JSONKeys.toDate.rawValue)
            multipartData.append(Data(scrapeTime.utf8), withName: JSONKeys.scrapeTime.rawValue)
        }
        
        client.executeAPI() { response, error in
            if let response = response as? APIResponse<ReportUpload> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "uploadFile", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReposneUplodFile))
                } else {
                    FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_uploadfile_api_success")
                    completionHandler(response.data, nil)
                }
            } else {
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_uploadfile_api_fail")
                completionHandler(nil, error)
            }
        }
        
        return client
    }
    
    static func getPIIList(completionHandler: @escaping ([PIIAttribute]?, ASLException?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<[PIIAttribute]>>(relativeURL: PIIListURL, requestMethod: .get)
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<[PIIAttribute]> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "getPIIList", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIReposnePIIList))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        
        return client
    }
    
    static func getAccounts(orderSource: [String], completionHandler: @escaping ([GetAccountsResponse]?, ASLException?) -> Void) -> APIClient {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let relativeUrl = GetAccounts + "/" + panelistId.lowercased()
        let client = NetworkClient<APIResponse<[GetAccountsResponse]>>(relativeURL: relativeUrl, requestMethod: .post)
        client.body = [JSONKeys.platformSources.rawValue: orderSource]
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<[GetAccountsResponse]> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "getAccounts", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error:  APIError(error: response.error ?? Strings.ErrorAPIReposneGetAccount))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        
        return client
    }
    
    static func registerConnection(platformId: String, status: String, message: String, orderStatus: String, orderSource: String, completionHandler: @escaping (AccountDetails?, ASLException?) -> Void) -> APIClient {
        let relativeURL = CreateConnection + "/" + orderSource
        let client = NetworkClient<APIResponse<AccountDetails>>(relativeURL: relativeURL, requestMethod: .post)

        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.panelistId.rawValue: panelistId.lowercased(), JSONKeys.platformId.rawValue: platformId.lowercased(),
                       JSONKeys.status.rawValue: status, JSONKeys.message.rawValue: message, JSONKeys.orderStatus.rawValue: orderStatus]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<AccountDetails> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "registerConnection", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error:  APIError(error: response.error ?? Strings.ErrorAPIReposneRegisterConnection))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        
        return client
    }
    
    static func updateStatus(platformId: String, status: String, message: String, orderStatus: String, orderSource: String,
                             completionHandler: @escaping (AccountDetails?, ASLException?) -> Void) -> APIClient {
        let relativeUrl = UpdateStatus + "/" + orderSource
        let client = NetworkClient<APIResponse<AccountDetails>>(relativeURL: relativeUrl, requestMethod: .put)
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        client.body = [JSONKeys.status.rawValue: status, JSONKeys.message.rawValue: message, JSONKeys.orderStatus.rawValue: orderStatus,JSONKeys.platformId.rawValue: platformId.lowercased(), JSONKeys.panelistId.rawValue: panelistId.lowercased()]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<AccountDetails> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "updateStatus", response.error ?? "Error")
                    FirebaseAnalyticsUtil.logSentryError(error: APIError(error: response.error ?? Strings.ErrorAPIResponseUpdateStatus))
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
                
                let panelistId = LibContext.shared.authProvider.getPanelistID()
                let logEventAttributes = [EventConstant.OrderSource: orderSource,
                                           EventConstant.OrderSourceID: platformId,
                                           EventConstant.PanelistID: panelistId,
                                           EventConstant.EventName: EventType.UpdateStatusAPIFailed,
                                           EventConstant.Status: EventStatus.Failure]
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
            }
        }
        return client
    }
    
   static func getScrapperConfig(orderSource: [String], completionHandler: @escaping (ScrapeConfigs?, ASLException?) -> Void) -> APIClient {
        
        let client = NetworkClient<APIResponse<ScrapeConfigs>>(relativeURL: ScrapperConfigURL, requestMethod: .post)
        client.body = [JSONKeys.configDetails.rawValue: orderSource]
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<ScrapeConfigs> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "getScrapperConfig", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        return client
    }
    
    static func fetchScript(orderSource: OrderSource, scriptType: String, completionHandler: @escaping (FetchScript?, ASLException?) -> Void) -> APIClient {
        let relativeUrl = FetchScript + "/" + orderSource.value + "/" + scriptType
        let client = NetworkClient<APIResponse<FetchScript>>(relativeURL: relativeUrl, requestMethod: .get)
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<FetchScript> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "fetchScript", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        return client
    }
    
    static func uploadOrderHistory(orderRequest: OrderRequest, orderSource: String, completionHandler:
                                    @escaping (OrderData?, ASLException?) -> Void) -> APIClient {
        let relativeURL = orderUpload + "/" + orderSource
        let client = NetworkClient<APIResponse<OrderData>>(relativeURL: relativeURL, requestMethod: .post)
        client.body = orderRequest.toDictionary()
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<OrderData> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "uploadOrderHistory error",response.error ?? "Error")
                } else {
                    completionHandler(response.data!, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        return client
    }

   static func getConfigs(completionHandler: @escaping (Configs?, ASLException?) -> Void) -> APIClient {
        let client = NetworkClient<APIResponse<Configs>>(relativeURL: GetConfigs, requestMethod: .get)
        
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<Configs> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "getConfigs", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        return client
    }
    

    static func logEvents(eventLogs: EventLogs, orderSource: String, completionHandler: @escaping (EventLogs?, ASLException?) -> Void) -> APIClient {
        let relativeURL = PostEvents + "/" +  orderSource
        let client = NetworkClient<APIResponse<EventLogs>>(relativeURL: relativeURL, requestMethod: .post)
        client.body = eventLogs.toDictionary()
        client.executeAPI() { (response, error) in
            if let response = response as? APIResponse<EventLogs> {
                if response.isError {
                    let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                    completionHandler(nil, aslException)
                    print(AppConstants.tag, "pushEvents", response.error ?? "Error")
                } else {
                    completionHandler(response.data, nil)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        return client
    }
    
    static func cancelAPI() {
        AF.cancelAllRequests()
    }
    
    static func getKrogerSusidiary(completionHandler: @escaping (KrogerSubsidiaries?, ASLException?) -> Void) -> APIClient {
         let client = NetworkClient<APIResponse<KrogerSubsidiaries>>(relativeURL: GetKrogerSubsidiary, requestMethod: .get, contentType: "text/html")
         
         client.executeAPI() { (response, error) in
             if let response = response as? APIResponse<KrogerSubsidiaries> {
                 if response.isError {
                     let aslException = ASLException(error: nil, errorMessage: response.error ?? "Error", failureType: nil)
                     completionHandler(nil, aslException)
                     print(AppConstants.tag, "getKrogerSusidiary", response.error ?? "Error")
                 } else {
                     completionHandler(response.data, nil)
                 }
             } else {
                 completionHandler(nil, error)
             }
         }
         return client
     }
}
