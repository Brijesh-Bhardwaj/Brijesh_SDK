//  BSScrapper.swift
//  OrderScrapper

import Foundation

class BSScrapper: NSObject {
    private let windowManager = BSHeadlessWindowManager()
    private var dateRange: DateRange?
    private var account: Account?
    let webClientDelegate = BSWebNavigationDelegate()
    let webClient: BSWebClient
    var completionHandler: ((Bool, OrderFetchSuccessType?), ASLException?) -> Void
    var authenticator: BSAuthenticator!
    var configuration: Configurations!
    
    init(webClient: BSWebClient,
         completionHandler: @escaping ((Bool, OrderFetchSuccessType?), ASLException?) -> Void) {
        self.webClient = webClient
        self.completionHandler = completionHandler
    }
    
    func startScrapping(account: Account) {
        windowManager.attachHeadlessView(view: webClient)
        self.account = account
        let orderSource = try! getOrderSource()
        
        _ = AmazonService.getDateRange(amazonId: account.userID){ response, error in
            if let dateRange = response {
                self.dateRange = dateRange
                if dateRange.enableScraping {
                    //Scrapping in the background
                    ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
                        if let configurations = configurations {
                            self.configuration = configurations
                            let authentiacator = try! self.getAuthenticator()
                            self.webClientDelegate.setObserver(observer: authentiacator as! BSWebNavigationObserver)
                            authentiacator.authenticate(account: account, configurations: configurations)
                        } else {
                            self.completionHandler((false, nil), ASLException(
                                                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
                        }
                    }
                } else {
                    self.completionHandler((false, .fetchSkipped), ASLException(
                                            errorMessage: Strings.ErrorFetchSkipped, errorType: nil))
                }
            } else {
                self.completionHandler((false, nil), ASLException(
                                        errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
            }
        }
    }
    
    func stopScrapping() {
        windowManager.detachHeadlessView(view: webClient)
    }
    
    func isScrapping() {
    }
    
    func getAuthenticator() throws -> BSAuthenticator {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
    
    func getOrderSource() throws -> OrderSource {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
}

extension BSScrapper: BSAuthenticationStatusListener {
    func onAuthenticationSuccess() {
        print("### onAuthenticationSuccess")
        let orderSource = try! getOrderSource()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: orderSource.value,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventorderListingAttributes:[String:String] = [:]
        logEventorderListingAttributes = [EventConstant.OrderSource: orderSource.value,
                                          EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventorderListingAttributes)
        
        //On authentication success load order listing page and inject JS script to get order Ids
        if let dateRange = self.dateRange {
            ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
                if let configurations = configurations {
                    BSScriptFileManager.shared.getScriptForScrapping(orderSource: orderSource){ script in
                        if let script = script {
                            
                            let urls = Urls(login: self.configuration.login, listing: self.configuration.listing, details: self.configuration.details)
                            let scriptBuilder = ScriptParam(script: script, dateRange: dateRange
                                                            , url: configurations.listing, scrappingPage: .listing, urls: urls,
                                                            orderId: nil)
                            let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptBuilder)
                            
                            BSHtmlScrapper(webClient: self.webClient, delegate: self.webClientDelegate, listener: self)
                                .extractOrders(script: executableScript, url: configurations.listing)
                            
                            var logEventAttributes:[String:String] = [:]
                            logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                                  EventConstant.PanelistID: self.account!.panelistID,
                                                  EventConstant.OrderSourceID: self.account!.userID,
                                                  EventConstant.Status: EventStatus.Success]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderListing, eventAttributes: logEventAttributes)
                        } else {
                            self.completionHandler((false, nil), ASLException(
                                                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
                        }
                    }
                } else {
                    self.completionHandler((false, nil), ASLException(
                                            errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
                }
            }
        } else {
            self.completionHandler((false, nil), ASLException(
                                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
        }
    }
    
    func onAuthenticationFailure(errorReason: ASLException) {
        print("### onAuthenticationFailure", errorReason.errorMessage)
        let orderSource = try! getOrderSource()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: orderSource.value,
                              EventConstant.ErrorReason: errorReason.errorMessage,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventOrderListingAttributes:[String:String] = [:]
        logEventOrderListingAttributes = [EventConstant.OrderSource: orderSource.value,
                                          EventConstant.ErrorReason: Strings.ErrorOrderListingNavigationFailed,
                                          EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventOrderListingAttributes)
        
        self.completionHandler((false, nil), errorReason)
    }
    
}

extension BSScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool) {
        print("### onScrapeDataUploadCompleted ", complete)
        let orderSource = try! getOrderSource()
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource:  orderSource.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID]
        
        if complete {
            self.completionHandler((true, .fetchCompleted), nil)
            logEventAttributes[EventConstant.Status] = EventStatus.Success
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)

        } else {
            self.completionHandler((false, nil), ASLException(
                                    errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
            logEventAttributes[EventConstant.Status] = EventStatus.Failure
            logEventAttributes[EventConstant.Reason] = Strings.ErrorOrderExtractionFailed
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
        }
    }
    
    func onHtmlScrappingSucess(response: String) {
        let jsonData = response.data(using: .utf8)!
        let scrapeResponse = try! JSONDecoder().decode(JSCallback<[OrderDetails]>.self, from: jsonData)
        
        if scrapeResponse.status == "success" {
            let orderDetails = scrapeResponse.data
            if let orderDetails = orderDetails, !orderDetails.isEmpty {
                insertOrderDetailsToDB(orderDetails: orderDetails) { dataInserted in
                    if dataInserted {
                        let orderSource = try! self.getOrderSource()
                        BSScriptFileManager.shared.getScriptForScrapping(orderSource: orderSource) { script in
                            if let script = script, let dateRange = self.dateRange {
                                let orderDetails = self.getOrderDetails()
                                
                                var logEventAttributes:[String:String] = [:]
                                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                                      EventConstant.PanelistID: self.account!.panelistID,
                                                      EventConstant.OrderSourceID: self.account!.userID,
                                                      EventConstant.Status: EventStatus.Success]
                                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderDetail, eventAttributes: logEventAttributes)
                                
                                BSOrderDetailsScrapper(webClient: self.webClient, delegate: self.webClientDelegate,
                                                       listener: self).scrapeOrderDetailPage(script: script, dateRange: dateRange, orderDetails: orderDetails)
                                print("### BSScrapper started scrapeOrderDetailPage")
                            } else {
                                self.completionHandler((false, nil), nil)
                            }
                        }
                    } else {
                        self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
                    }
                }
            } else {
                self.completionHandler((true, .fetchCompleted), nil)
            }
        } else {
            self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
        }
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderListResult, eventAttributes: logEventAttributes)
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.completionHandler((false, nil), error)
    }
    
    func insertOrderDetailsToDB(orderDetails: [OrderDetails], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            for orderDetail in orderDetails {
                orderDetail.userID = self.account!.userID
                orderDetail.panelistID = self.account!.panelistID
                orderDetail.orderSource = try! self.getOrderSource().value
                orderDetail.date = DateUtils.getDate(dateStr: orderDetail.orderDate)
            }
            CoreDataManager.shared.insertOrderDetails(orderDetails: orderDetails)
            DispatchQueue.main.async {
                completion(true)
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInsertScrappedOrderDetailsInDB, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func getOrderDetails() -> [OrderDetailsMO]{
       let orderDetails = CoreDataManager.shared.fetchOrderDetails(orderSource: try! self.getOrderSource().value, panelistID: self.account!.panelistID, userID: self.account!.userID)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                              EventConstant.PanelistID: account!.panelistID,
                              EventConstant.OrderSourceID: account!.userID,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrappedOrderDetailsFromDB, eventAttributes: logEventAttributes)

        return orderDetails
    }
}

extension BSScrapper: BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?) {
        
    }
    
    func didStartPageNavigation(url: URL?) {
        
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        
    }
}
