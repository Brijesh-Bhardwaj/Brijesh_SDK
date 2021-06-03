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
                            let scriptBuilder = ScriptParam(script: script, dateRange: dateRange
                                                            , url: configurations.listing, scrappingPage: .listing)
                            let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptBuilder)
                            
                            BSHtmlScrapper(webClient: self.webClient, delegate: self.webClientDelegate, listener: self)
                                .extractOrders(script: executableScript, url: configurations.listing)
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
    func onHtmlScrappingSucess(response: String) {
        insertOrderDetailsToDB(response: response) { dataInserted in
            if dataInserted {
                self.getOrderDetails()
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.completionHandler((false, nil), error)
    }
    
    func insertOrderDetailsToDB(response: String, completion: @escaping (Bool) -> Void) {
        if !response.isEmpty {
            DispatchQueue.global().async {
                let jsonData = response.data(using: .utf8)!
                let scrapeResponse = try! JSONDecoder().decode(ScrapeResponse.self, from: jsonData)
                let orderScrapeData = scrapeResponse.data
                if let orderScrapeData = orderScrapeData, !orderScrapeData.isEmpty {
                    
                    for orderDetail in orderScrapeData {
                        orderDetail.userID = self.account!.userID
                        orderDetail.panelistID = self.account!.panelistID
                        orderDetail.orderSource = try! self.getOrderSource().value
                        orderDetail.date = DateUtils.getDate(dateStr: orderDetail.orderDate)
                    }
                    CoreDataManager.shared.insertOrderDetails(orderDetails: orderScrapeData)
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        } else {
            completion(true)
        }
    }
    
    func getOrderDetails() {
        _ = CoreDataManager.shared.fetchOrderDetails(orderSource: try! self.getOrderSource().value, panelistID: self.account!.panelistID, userID: self.account!.userID)
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
