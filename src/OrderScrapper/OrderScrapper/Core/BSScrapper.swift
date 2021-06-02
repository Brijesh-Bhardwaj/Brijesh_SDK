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
        self.completionHandler((true, .fetchCompleted), nil)
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.completionHandler((false, nil), error)
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
