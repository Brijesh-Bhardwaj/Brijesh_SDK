//  BSScriptFileManager.swift
//  OrderScrapper

import Foundation

class BSScriptFileManager {
    private static var instance: BSScriptFileManager!
    var authenticationScripts = Dictionary<OrderSource, [String: String]>()
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
                        
                        let filePath = FileHelper.getScriptFilePath(orderSource: orderSource, isAuthScript: ScriptType.scrape.rawValue)
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
    func getScriptForScrapping(orderSource: OrderSource, scriptType: String, completion: @escaping (String?) -> Void) {
        _ = AmazonService.fetchScript(orderSource: orderSource, scriptType: scriptType) { response, error in
            if let response = response {
                let jsVersion = response.jsVersion
                var lastJSVersion = ""
                let jsUrl = response.jsUrl
                if scriptType == ScriptType.auth.rawValue {
                    lastJSVersion = UserDefaults.standard.string(forKey: Utils.getKeyForAuthJSVersion(orderSorce: orderSource)) ?? ""
                } else {
                    lastJSVersion = UserDefaults.standard.string(forKey: Utils.getKeyForJSVersion(orderSorce: orderSource)) ?? ""
                }
                //If we get the updated js version then download script file for it
                if !jsVersion.isEmpty && jsVersion == lastJSVersion {
                    let scriptFileExist = FileHelper.isScriptFileExist(orderSource: orderSource, isAuthScript: scriptType)
                    if scriptFileExist {
                        let filePath = FileHelper.getScriptFilePath(orderSource: orderSource, isAuthScript: scriptType)
                        let script = FileHelper.getDataFromFile(fileUrl: filePath)
                        completion(script)
                    } else {
                        self.getScriptFile(jsUrl: jsUrl, jsVersion: jsVersion, orderSource: orderSource, isAuthScript: scriptType) { script in
                            if let script = script {
                                completion(script)
                            } else {
                                completion(nil)
                            }
                        }
                    }
                } else {
                    self.getScriptFile(jsUrl: jsUrl, jsVersion: jsVersion, orderSource: orderSource, isAuthScript: scriptType) { script in
                        if let script = script {
                            completion(script)
                        } else {
                            completion(nil)
                        }
                    }
                }
            } else {
                completion(nil)
            }
        }
    }
    //API call for fetchScript
    func getScriptFetchUrl(orderSource: OrderSource, completion: @escaping (FetchScript?, Error?) -> Void) {
        _ = AmazonService.fetchScript(orderSource: orderSource, scriptType: ScriptType.scrape.rawValue) { response, error in
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
    
    func getScriptFile(jsUrl: String, jsVersion: String, orderSource: OrderSource, isAuthScript: String, completion: @escaping (String?) -> Void) {
        let url = LibContext.shared.orderExtractorConfig.baseURL + jsUrl
        let scriptFileUrl = URL(string: url)
        
        var urlRequest = URLRequest(url: scriptFileUrl!)
        urlRequest.addValue("Bearer " + LibContext.shared.authProvider.getAuthToken(), forHTTPHeaderField: "Authorization")
        urlRequest.addValue(LibContext.shared.authProvider.getPanelistID(), forHTTPHeaderField: "panelist_id")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let filePath = FileHelper.getScriptFilePath(orderSource: orderSource, isAuthScript: isAuthScript)
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
                    if isAuthScript == ScriptType.auth.rawValue {
                        UserDefaults.standard.setValue(jsVersion, forKey: Utils.getKeyForAuthJSVersion(orderSorce: orderSource))
                    } else {
                        UserDefaults.standard.setValue(jsVersion, forKey: Utils.getKeyForJSVersion(orderSorce: orderSource))
                    }
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
    }
    

    func getAuthenticationScripts(orderSource: OrderSource, isAuthScript: String, completionHandler: @escaping (Bool) -> Void) {
        self.getScriptForScrapping(orderSource: orderSource, scriptType: isAuthScript) { [self] script in
            if let script = script {
                authenticationScripts[orderSource] = nil
                self.parseData(orderSource: orderSource, data: script) { response in
                    if !response.isEmpty {
                        completionHandler (true)
                    } else {
                        completionHandler(false)
                    }
                }
            } else {
                completionHandler(false)
            }
        }
    }
    
    private func parseData(orderSource: OrderSource, data: String, completionHandler: @escaping (Dictionary<OrderSource, [String: String]>) -> Void)  {
        if let data = data.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                    for item in json {
                        if item.key == "ios" {
                            let scriptDict = item.value as! Dictionary<String, String>
                            authenticationScripts[orderSource] = scriptDict
                        }
                    }
                }
            } catch {
                let logEvents = EventLogs(panelistId: LibContext.shared.authProvider.getPanelistID(), platformId: nil, section: SectionType.connection.rawValue, type: FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: AppConstants.ScriptParseError, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
                self.logEvent(eventLog: logEvents, orderSource: orderSource)
                print("Something went wrong file format is wrong")
            }
        } else {
            let logEvents = EventLogs(panelistId: LibContext.shared.authProvider.getPanelistID(), platformId: nil, section: SectionType.connection.rawValue, type: FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: AppConstants.authScriptFileNotFound, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
            self.logEvent(eventLog: logEvents, orderSource: orderSource)
            print("File not found")
         }
        completionHandler(authenticationScripts)
    }
    
    private func logEvent(eventLog: EventLogs, orderSource: OrderSource) {
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource.value) { response, error in
             
            
        }
        
    }
    
    func getAuthScript(orderSource: OrderSource, scriptKey: String, completionHandler: @escaping (String) -> Void) {
        var srciptData = ""
        if let scriptKeys = authenticationScripts[orderSource] {
            if let scriptData = scriptKeys[scriptKey] {
                srciptData = scriptData
                completionHandler(srciptData)
            }
        } else {
            self.getAuthenticationScripts(orderSource: orderSource, isAuthScript: ScriptType.auth.rawValue) { response in
                if response {
                    if let scriptKeys = self.authenticationScripts[orderSource] {
                        if let scriptData = scriptKeys[scriptKey] {
                            srciptData = scriptData
                            completionHandler(srciptData)
                        }
                    } else {
                        completionHandler(srciptData)
                    }
                } else {
                    completionHandler(srciptData)
                }
            }
        }
    }
}
