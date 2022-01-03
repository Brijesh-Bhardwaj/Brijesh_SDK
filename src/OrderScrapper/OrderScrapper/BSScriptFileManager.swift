//  BSScriptFileManager.swift
//  OrderScrapper

import Foundation

class BSScriptFileManager {
    private static var instance: BSScriptFileManager!
    private init() {
    }
    
    static var shared: BSScriptFileManager = {
        if instance == nil {
            instance = BSScriptFileManager()
        }
        return instance
    }()
    
    func loadScriptFile() {
        self.getScript(orderSources: [.Amazon,.Instacart,.Kroger,.Walmart]) { script in
        }
    }
    
    private func getScript(orderSources: [OrderSource], completion: @escaping (String?) -> Void) {
        for orderSource in orderSources {
            self.getScriptFetchUrl(orderSource: orderSource) { response, error in
                if let response = response {
                    let jsUrl = response.jsUrl
                    let jsVersion = response.jsVersion
                    let lastJSVersion = UserDefaults.standard.string(forKey: Utils.getKeyForJSVersion(orderSorce: orderSource))
                    //If we get the updated js version then download script file for it
                    if !jsVersion.isEmpty && jsVersion != lastJSVersion {
                        let url = LibContext.shared.orderExtractorConfig.baseURL + jsUrl
                        let scriptFileUrl = URL(string: url)
                        
                        var urlRequest = URLRequest(url: scriptFileUrl!)
                        urlRequest.addValue("Bearer " + LibContext.shared.authProvider.getAuthToken(), forHTTPHeaderField: "Authorization")
                        urlRequest.addValue(LibContext.shared.authProvider.getPanelistID(), forHTTPHeaderField: "panelist_id")
                        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                        
                        let filePath = FileHelper.getScriptFilePath(orderSource: orderSource)
                        //download script file
                        let downloader = FileDownloader()
                        downloader.downloadFile(urlRequest: urlRequest, destinationFilePath: filePath) { filePath, error in
                            var logEventAttributes:[String:String] = [EventConstant.OrderSource: orderSource.value,
                                                                      EventConstant.PanelistID: LibContext.shared.authProvider.getPanelistID()]
                            
                            if let filePath = filePath {
                                logEventAttributes[EventConstant.Status] = EventStatus.Success
                                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgDownloadScrapperScriptFile, eventAttributes: logEventAttributes)
                                
                                var logEventRetrieveScriptAttributes:[String:String] = [EventConstant.OrderSource: orderSource.value,EventConstant.PanelistID: LibContext.shared.authProvider.getPanelistID()]
                                
                                let script = FileHelper.getDataFromFile(fileUrl: filePath)
                                if let script = script {
                                    UserDefaults.standard.setValue(jsVersion, forKey: Utils.getKeyForJSVersion(orderSorce: orderSource))
                                    completion(script)
                                    
                                    logEventRetrieveScriptAttributes[EventConstant.Status] = EventStatus.Success
                                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrapperScript, eventAttributes: logEventRetrieveScriptAttributes)
                                } else {
                                    completion(nil)
                                    
                                    logEventRetrieveScriptAttributes[EventConstant.ErrorReason] = Strings.ErrorScriptNotFound
                                    logEventRetrieveScriptAttributes[EventConstant.Status] = EventStatus.Failure
                                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrapperScript, eventAttributes: logEventRetrieveScriptAttributes)
                                }
                            } else {
                                completion(nil)
                                
                                logEventAttributes[EventConstant.ErrorReason] = Strings.ErrorScriptFileNotFound
                                logEventAttributes[EventConstant.Status] = EventStatus.Failure
                                FirebaseAnalyticsUtil.logEvent(eventType: EventType.FailureWhileDownloadingScript, eventAttributes: logEventAttributes)
                            }
                        }
                    } else {
                        completion(nil)

                    }
                }
            }
        }
    }
    //Returns script for scrapping
    func getScriptForScrapping(orderSource: OrderSource, completion: @escaping (String?) -> Void) {
        let scriptFileExist = FileHelper.isScriptFileExist(orderSource: orderSource)
        if scriptFileExist {
            let filePath = FileHelper.getScriptFilePath(orderSource: orderSource)
            let script = FileHelper.getDataFromFile(fileUrl: filePath)
            completion(script)
        } else {
            self.getScript(orderSources: [orderSource]) { script in
                var logEventRetrieveScriptAttributes:[String:String] = [EventConstant.OrderSource: orderSource.value,EventConstant.PanelistID: LibContext.shared.authProvider.getPanelistID()]
                
                if let script = script {
                    completion(script)
                    
                    logEventRetrieveScriptAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrapperScript, eventAttributes: logEventRetrieveScriptAttributes)
                } else {
                    completion(nil)
                    
                    logEventRetrieveScriptAttributes[EventConstant.Status] = EventStatus.Failure
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileLoadingScrapingScript, eventAttributes: logEventRetrieveScriptAttributes)
                }
            }
        }
    }
    //API call for fetchScript
    func getScriptFetchUrl(orderSource: OrderSource, completion: @escaping (FetchScript?, Error?) -> Void) {
        _ = AmazonService.fetchScript(orderSource: orderSource) { response, error in
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: orderSource.value,
                                      EventConstant.PanelistID: panelistId]
            if let response = response {
                completion(response, nil)
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIFetchScript, eventAttributes: logEventAttributes)
            } else {
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                completion(nil, APIError(error: error.debugDescription))
            }
        }
    }
}
