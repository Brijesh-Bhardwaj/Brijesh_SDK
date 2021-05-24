//  BSScrapper.swift
//  OrderScrapper

import Foundation

class BSScrapper: NSObject, BSAuthenticationStatusListener {
    private let webClientDelegate = BSWebNavigationDelegate()
    private let windowManager = BSHeadlessWindowManager()
    
    let webClient: BSWebClient
    var authenticator: BSAuthenticator!
    var completionHandler: ((Bool, OrderFetchSuccessType?), ASLException?) -> Void
    var configuration: Configurations!
    
    init(webClient: BSWebClient,
         completionHandler: @escaping ((Bool, OrderFetchSuccessType?), ASLException?) -> Void) {
        self.webClient = webClient
        self.completionHandler = completionHandler
    }
    
    func startScrapping(account: Account) {
        windowManager.attachHeadlessView(view: webClient)
        
        let orderSource = try! getOrderSource()
        ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
            if let configurations = configurations {
                self.configuration = configurations
                let authentiacator = try! self.getAuthenticator()
                self.webClientDelegate.setObserver(observer: authentiacator as! BSWebNavigationObserver)
                authentiacator.authenticate(account: account, configurations: configurations)
            } else {
                self.onAuthenticationFailure(errorReason: ASLException(
                                                errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
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
    
    func onAuthenticationSuccess() {
        print("### onAuthenticationSuccess")
        let orderSource = try! getOrderSource()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventorderListingAttributes:[String:String] = [:]
        logEventorderListingAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                                          EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventorderListingAttributes)
        
        //Load Order Listing page
        ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
            if let configurations = configurations {
                let orderListingUrl = configurations.listing
                self.webClient.loadUrl(url: orderListingUrl)
            }
        }
        self.completionHandler((true, .fetchCompleted), nil)
    }
    
    func onAuthenticationFailure(errorReason: ASLException) {
        print("### onAuthenticationFailure", errorReason.errorMessage)
        let orderSource = try! getOrderSource()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                              EventConstant.ErrorReason: errorReason.errorMessage,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventOrderListingAttributes:[String:String] = [:]
        logEventOrderListingAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                                          EventConstant.ErrorReason: Strings.ErrorOrderListingNavigationFailed,
                                          EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventOrderListingAttributes)
        self.completionHandler((false, nil), errorReason)
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
