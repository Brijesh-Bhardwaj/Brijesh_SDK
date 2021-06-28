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
    var configuration: Configurations!
    var extractingOldOrders = false;
    
    lazy var scrapperParams: BSHtmlScrapperParams = {
        let authenticator = try! self.getAuthenticator()
        
        return BSHtmlScrapperParams(webClient: self.webClient, webNavigationDelegate: self.webClientDelegate, listener: self, authenticator: authenticator, configuration: self.configuration, account: self.account!)
    }()
    
    lazy var authenticator: BSAuthenticator = {
        let authenticator = try! self.getAuthenticator()
        return authenticator
    }()
    
    lazy var orderSource: OrderSource = {
        let source = try! self.getOrderSource()
        return source
    }()
    
    init(webClient: BSWebClient,
         completionHandler: @escaping ((Bool, OrderFetchSuccessType?), ASLException?) -> Void) {
        self.webClient = webClient
        self.webClient.navigationDelegate = self.webClientDelegate
        self.completionHandler = completionHandler
    }
    
    func startScrapping(account: Account) {
        windowManager.attachHeadlessView(view: webClient)
        self.account = account
        
        let dbOrderDetails = self.getOrderDetails()
        if dbOrderDetails.count > 0 {
            self.uploadPreviousOrders()
        } else {
            self.extractNewOrders()
        }
    }
    
    func stopScrapping() {
        DispatchQueue.main.async {
            self.webClient.navigationDelegate = nil
            self.webClient.stopLoading()
            self.cleanUp()
        }
    }
    
    func isScrapping() {
    }
    
    func getAuthenticator() throws -> BSAuthenticator {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
    
    func getOrderSource() throws -> OrderSource {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
    
    private func cleanUp() {
        self.windowManager.detachHeadlessView(view: self.webClient)
    }
    
    private func uploadPreviousOrders() {
        extractingOldOrders = true
        ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { (configuration, error) in
            if let configuration = configuration {
                self.configuration = configuration
                self.didInsertToDB()
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), ASLException(
                                        errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
            }
        }
    }
    
    private func extractNewOrders() {
        extractingOldOrders = false
        _ = AmazonService.getDateRange(amazonId: self.account!.userID){ response, error in
            if let dateRange = response {
                self.didReceive(dateRange: dateRange)
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), ASLException(
                                        errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
            }
        }
    }
    
    private func didReceive(dateRange: DateRange) {
        if dateRange.enableScraping {
            self.dateRange = dateRange
            
            ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { configurations, error in
                if let configurations = configurations {
                    self.didReceive(configuration: configurations)
                } else {
                    self.stopScrapping()
                    self.completionHandler((false, nil), ASLException(
                                            errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
                }
            }
        } else {
            self.stopScrapping()
            self.completionHandler((false, .fetchSkipped), ASLException(
                                    errorMessage: Strings.ErrorFetchSkipped, errorType: nil))
        }
    }
    
    private func didReceive(configuration: Configurations) {
        self.configuration = configuration
        BSScriptFileManager.shared.getScriptForScrapping(orderSource: self.orderSource) { script in
            if let script = script {
                let urls = Urls(login: self.configuration.login, listing: self.configuration.listing, details: self.configuration.details)
                let scriptBuilder = ScriptParam(script: script, dateRange: self.dateRange
                                                , url: self.configuration.listing, scrappingPage: .listing, urls: urls,
                                                orderId: nil)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptBuilder)
                
                BSHtmlScrapper(params: self.scrapperParams)
                    .extractOrders(script: executableScript, url: self.configuration.listing)
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderListing, eventAttributes: logEventAttributes)
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), ASLException(
                                        errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
            }
        }
    }
}

extension BSScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool, error: ASLException?) {
        print("### onScrapeDataUploadCompleted ", complete)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource:  self.orderSource.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID]
        if extractingOldOrders {
            self.extractNewOrders()
        } else {
            if complete {
                self.completionHandler((true, .fetchCompleted), nil)
                logEventAttributes[EventConstant.Status] = EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
            } else {
                self.completionHandler((false, nil), error!)
                logEventAttributes[EventConstant.Status] = EventStatus.Failure
                logEventAttributes[EventConstant.Reason] = Strings.ErrorOrderExtractionFailed
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
            }
            self.stopScrapping()
        }
    }
    
    func onHtmlScrappingSucess(response: String) {
        let jsonData = response.data(using: .utf8)!
        let scrapeResponse = try? JSONDecoder().decode(JSCallback<[OrderDetails]>.self, from: jsonData)
        print("#### onHtmlScrappingSucess BSCrapper ", response)
        if scrapeResponse?.type == "order\(ScrappingPage.details.rawValue)" {
            return
        }
        
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: self.orderSource.value,
                                                  EventConstant.PanelistID: self.account!.panelistID,
                                                  EventConstant.OrderSourceID: self.account!.userID]
        if scrapeResponse?.type == "orderlist" {
            if scrapeResponse?.status == "success" {
                if let orderDetails = scrapeResponse?.data, !orderDetails.isEmpty {
                    insertOrderDetailsToDB(orderDetails: orderDetails) { dataInserted in
                        if dataInserted {
                            self.didInsertToDB()
                        } else {
                            self.stopScrapping()
                            self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
                        }
                    }
                } else {
                    self.stopScrapping()
                    self.completionHandler((true, .fetchCompleted), nil)
                }
                
                logEventAttributes[EventConstant.Status] =  EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderListResult, eventAttributes: logEventAttributes)
            } else if scrapeResponse?.status == "failed" {
                self.stopScrapping()
                self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
                
                var error: String
                if let errorReason = scrapeResponse?.errorMessage {
                    error = errorReason
                } else {
                    error = Strings.ErrorOrderExtractionFailed
                }
                
                logEventAttributes[EventConstant.ErrorReason] =  error
                logEventAttributes[EventConstant.Status] =  EventStatus.Failure
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderListResult, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.stopScrapping()
        self.completionHandler((false, nil), error)
    }
    
    func insertOrderDetailsToDB(orderDetails: [OrderDetails], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            for orderDetail in orderDetails {
                orderDetail.userID = String(self.account!.userID)
                orderDetail.panelistID = String(self.account!.panelistID)
                orderDetail.orderSource = String(self.orderSource.value)
                orderDetail.startDate = self.dateRange?.fromDate
                orderDetail.endDate = self.dateRange?.toDate
                orderDetail.date = DateUtils.getDate(dateStr: orderDetail.orderDate)
            }
            CoreDataManager.shared.insertOrderDetails(orderDetails: orderDetails) { status in
                DispatchQueue.main.async {
                    completion(true)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                          EventConstant.PanelistID: self.account!.panelistID,
                                          EventConstant.OrderSourceID: self.account!.userID,
                                          EventConstant.Status: EventStatus.Success]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInsertScrappedOrderDetailsInDB, eventAttributes: logEventAttributes)
                }
            }
        }
    }
    
    func getOrderDetails() -> [OrderDetailsMO] {
        let orderDetails = CoreDataManager.shared.fetchOrderDetails(orderSource: try! self.getOrderSource().value, panelistID: self.account!.panelistID, userID: self.account!.userID)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                              EventConstant.PanelistID: account!.panelistID,
                              EventConstant.OrderSourceID: account!.userID,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrappedOrderDetailsFromDB, eventAttributes: logEventAttributes)
        
        return orderDetails
    }
    
    private func didInsertToDB() {
        BSScriptFileManager.shared.getScriptForScrapping(orderSource: self.orderSource) { script in
            if let script = script {
                let orderDetails = OrderDetailsMapper.mapFromDBObject(dbOrderDetails: self.getOrderDetails())
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderDetail, eventAttributes: logEventAttributes)
                
                BSOrderDetailsScrapper(scrapperParams: self.scrapperParams).scrapeOrderDetailPage(script: script, orderDetails: orderDetails)
                print("### BSScrapper started scrapeOrderDetailPage")
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), nil)
            }
        }
    }
}
