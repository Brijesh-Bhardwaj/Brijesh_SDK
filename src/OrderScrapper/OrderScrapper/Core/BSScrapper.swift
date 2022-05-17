//  BSScrapper.swift
//  OrderScrapper

import Foundation
import Sentry

public enum HtmlScrappingStep: Int16 {
    case startScrapping = 1,
         listing = 2,
         complete = 3
    var value: String {
        return String(describing: self)
    }
}

class BSScrapper: NSObject, TimerCallbacks, ScraperProgressListener {
    private let windowManager = BSHeadlessWindowManager()
    var dateRange: DateRange?
    var account: Account?
    let webClientDelegate = BSWebNavigationDelegate()
    let webClient: BSWebClient
    var completionHandler: ((Bool, OrderFetchSuccessType?), ASLException?) -> Void
    var configuration: Configurations!
    var extractingOldOrders = false;
    var timer = BSTimer()
    var orderDetails = BSTimer()
    var scrappingType: String!
    public var scraperListener: ScraperProgressListener?
    public var scrappingMode: ScrapingMode?
    var fetchRequestSource: FetchRequestSource?
    let panelistID = LibContext.shared.authProvider.getPanelistID()
    var isNewSession = false
    var bsHtmlScrapper: BSHtmlScrapper! = nil
    var scraperParams: BSHtmlScrapperParams! = nil
    var getScrapeSessionTimer: String? = nil
    var scrapingSessionEndedAt: String? = nil
    var sessionId: String? = UUID().uuidString
    
    private func getBSHtmlScrapper () -> BSHtmlScrapper {
        if bsHtmlScrapper == nil {
            bsHtmlScrapper = BSHtmlScrapper(params: self.getScraperParams())
        }
        return bsHtmlScrapper
    }
    
    private func getScraperParams() -> BSHtmlScrapperParams {
        if scraperParams == nil {
            let authenticator = try! self.getAuthenticator()
            scraperParams =  BSHtmlScrapperParams(webClient: self.webClient, webNavigationDelegate: self.webClientDelegate, listener: self, authenticator: authenticator, configuration: self.configuration, account: self.account!, scrappingType: self.scrappingType, scrappingMode: scrappingMode?.rawValue)
        }
        return scraperParams
    }
    
    lazy var authenticator: BSAuthenticator = {
        let authenticator = try! self.getAuthenticator()
        return authenticator
    }()
    
    lazy var orderSource: OrderSource = {
        let source = try! self.getOrderSource()
        return source
    }()
    
    lazy var CSVScrapper: BSCSVScrapper = {
        return BSCSVScrapper(webview: self.webClient, scrapingMode: .Background, scraperListener: self)
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
        getScrapeSessionTimer = DateUtils.getSessionTimer()
        if self.fetchRequestSource == .online || self.fetchRequestSource == .manual {
            self.extractNewOrders()
        } else {
            DispatchQueue.global().async {
                let dbOrderDetails = self.getOrderDetails()
                if dbOrderDetails.count > 0 {
                    self.uploadPreviousOrders()
                } else {
                    self.extractNewOrders()
                }
            }
        }
    }
    func stopScrapping() {
        DispatchQueue.main.async {
            self.webClient.navigationDelegate = nil
            self.webClient.stopLoading()
            self.cleanUp()
        }
    }
    
    func stopOnlineScrapping() {
        DispatchQueue.main.async {
            self.webClient.stopLoading()
            self.cleanUp()
        }
    }
    func isScrapping() {
    }
    
    func getAuthenticator() throws -> BSAuthenticator {
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                              EventConstant.PanelistID: panelistID,
                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                              EventConstant.ScrappingType: scrappingType,
                              EventConstant.EventName: EventType.ExceptionWhileGettingAuthenticator,
                              EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        throw error
    }
    
    func getOrderSource() throws -> OrderSource {
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        var logEventAttributes:[String:String] = [:]

        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                              EventConstant.PanelistID: panelistID,
                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                              EventConstant.ScrappingType: scrappingType,
                              EventConstant.EventName: EventType.ExceptionWhileGettingOrderSource,
                              EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        throw error
    }
    
    private func cleanUp() {
        self.windowManager.detachHeadlessView(view: self.webClient)
    }
    
    private func uploadPreviousOrders() {
        Utils.isListScrapping(isListScrapping:false)
        if fetchRequestSource == .online || fetchRequestSource == .manual {
            extractingOldOrders = false
            updateProgressViewLabel(isUploadingPreviousOrder: false)
        } else {
            extractingOldOrders = true
            updateProgressViewLabel(isUploadingPreviousOrder: true)
        }
        ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { (configuration, error) in
            if let configuration = configuration {
                self.configuration = configuration
                self.didInsertToDB()
            } else {
                self.stopScrapping()
                if let error = error {
                    var logEventAttributes:[String:String] = [:]

                    logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                          EventConstant.PanelistID: self.panelistID,
                                          EventConstant.OrderSourceID: self.account?.userID ?? "",
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    if let scrappingMode = self.scrappingMode {
                        logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                    }
                    if let scrappingType = self.scrappingType {
                        logEventAttributes[EventConstant.ScrappingType] = scrappingType
                    }
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                
                let error = ASLException(
                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                self.completionHandler((false, nil), error)
            }
        }
    }
    
    private func extractNewOrders() {
        Utils.isListScrapping(isListScrapping:true)
        extractingOldOrders = false

        updateProgressValue(progressValue: 20)
        updateProgressViewLabel(isUploadingPreviousOrder: false)
        if let listener = self.scraperListener {
            listener.updateProgressStep(htmlScrappingStep: .startScrapping)
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                  EventConstant.PanelistID: panelistID,
                                  EventConstant.OrderSourceID: self.account?.userID ?? "",
                                  EventConstant.ScrappingStep: HtmlScrappingStep.startScrapping.value,
                                  EventConstant.Status: EventStatus.Success]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepStarHtmlScrapping, eventAttributes: logEventAttributes)
        }
        var forceScrape = false
        var sessionScrapeTimer: String? = nil
        if let source = self.fetchRequestSource, source == .manual || source == .online {
            //For manual scraping send forcescrape as true to date range API
            if fetchRequestSource == .online {
                isNewSession = true
            }
            forceScrape = true
        }
        _ = AmazonService.getDateRange(platformId: self.account!.userID,
                                       orderSource: self.orderSource.value, forceScrape: forceScrape) { response, error in
            if let dateRange = response {
                self.didReceive(dateRange: dateRange)
                var json: String
                do {
                    let jsonData = try JSONEncoder().encode(response)
                    json = String(data: jsonData, encoding: .utf8)!
                } catch {
                    json = AppConstants.ErrorInJsonEncoding
                }
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                      EventConstant.PanelistID: self.panelistID,
                                      EventConstant.OrderSourceID: self.account?.userID ?? "",
                                      EventConstant.ScrappingStep: HtmlScrappingStep.startScrapping.value,
                                      EventConstant.Data: json,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            } else {
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback(error: error)
                } else {
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                                          EventConstant.PanelistID: self.account!.panelistID,
                                          EventConstant.OrderSourceID: self.account!.userID,
                                          EventConstant.ScrappingStep: HtmlScrappingStep.startScrapping.value,
                                          EventConstant.EventName: EventType.ExceptionWhileDateRangeAPI,
                                          EventConstant.Status: EventStatus.Failure]
                    if let error = error {
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileDateRangeAPI, eventAttributes: logEventAttributes)
                    }
                    
                    self.stopScrapping()
                    let error = ASLException(
                        errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
                    self.completionHandler((false, nil),error )
                }
            }
        }
    }
    
    private func didReceive(dateRange: DateRange) {
        if dateRange.enableScraping {
            self.dateRange = dateRange
            self.scrappingType = dateRange.scrappingType
            
            ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { configurations, error in
                if let configurations = configurations {
                    self.didReceive(configuration: configurations)
                } else {
                    self.stopScrapping()
                    
                    if let error = error {
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                              EventConstant.PanelistID: self.panelistID,
                                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                                              EventConstant.ScrappingType: dateRange.scrappingType ?? "",
                                              EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                              EventConstant.Status: EventStatus.Failure]
                        if let scrappingMode = self.scrappingMode {
                            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                        }
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    }
                    
                    let error = ASLException(
                        errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                    self.completionHandler((false, nil), error)
                }
            }
        } else {
            self.stopScrapping()
            
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                  EventConstant.PanelistID: self.panelistID,
                                  EventConstant.OrderSourceID: self.account?.userID ?? "",
                                  EventConstant.ScrappingType: dateRange.scrappingType ?? "",
                                  EventConstant.Status: EventStatus.Success]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.ScrappingDisable, eventAttributes: logEventAttributes)
            
            let error =  ASLException(
                errorMessage: Strings.ErrorFetchSkipped, errorType: nil)
            self.completionHandler((false, .fetchSkipped), error)
        }
    }
    
    private func didReceive(configuration: Configurations) {
        self.configuration = configuration
        BSScriptFileManager.shared.getScriptForScrapping(orderSource: self.orderSource, scriptType: ScriptType.scrape.rawValue) { script in
            if let script = script {
                self.timer.start()
                let urls = Urls(login: self.configuration.login, listing: self.configuration.listing, details: self.configuration.details)
                let scriptBuilder = ScriptParam(script: script, dateRange: self.dateRange
                                                , url: self.configuration.listing, scrappingPage: .listing, urls: urls,
                                                orderId: nil, orderDate: nil)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptBuilder)
                
                if self.dateRange?.scrappingType == ScrappingType.report.rawValue {
                    let timerHandler = TimerHandler(timerCallback: self)
                    self.CSVScrapper.scrapeOrders(response: self.dateRange!, account: self.account!
                                                  , timerHandler: timerHandler, param: self.getScraperParams())
                } else {
                    self.getBSHtmlScrapper().extractOrders(script: executableScript, url: self.configuration.listing)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                          EventConstant.PanelistID: self.panelistID,
                                          EventConstant.OrderSourceID: self.account?.userID ?? "",
                                          EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                          EventConstant.Status: EventStatus.Success]
                    
                    if let scrappingMode = self.scrappingMode {
                        logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                    }
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderListing, eventAttributes: logEventAttributes)
                }
            } else {
                self.stopScrapping()
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                      EventConstant.PanelistID: self.panelistID,
                                      EventConstant.OrderSourceID: self.account?.userID ?? "",
                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                      EventConstant.Status: EventStatus.Success]
                
                if let scrappingMode = self.scrappingMode {
                    logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                }
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileLoadingScrapingScript, eventAttributes: logEventAttributes)
                
                let error = ASLException(
                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                self.completionHandler((false, nil), error)
            }
        }
    }
    
    func onTimerTriggered(action: String) {
        self.stopScrapping()
        let panelistID = self.account?.panelistID ?? ""
        let platformId = self.account?.userID ?? ""
        let orderSource = self.account?.source.value ?? ""
        logPushEvent(panelistID:panelistID,platformId:platformId,failureType:LibContext.shared.timeoutType,orderSource:orderSource)
        let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                              EventConstant.PanelistID: self.panelistID,
                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                              EventConstant.ScrappingType: ScrappingType.html.rawValue,
                              EventConstant.EventName: EventType.TimeoutOccurred,
                              EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        
        self.completionHandler((false, nil), error)
    }
    
    private func logPushEvent(panelistID:String,platformId:String,failureType:String,orderSource:String){
        let eventLogs = EventLogs(panelistId: panelistID, platformId:platformId, section: SectionType.orderUpload.rawValue, type: failureType, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: self.dateRange?.fromDate, toDate: self.dateRange?.toDate, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url: webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: orderSource) { response, error in
            self.sendServicesDownCallback(error: error)
        }
    }
    
    func onWebviewError(isError: Bool) {
        if isError {
            self.stopScrapping()
            let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
            self.completionHandler((false, nil), error)
        }
    }
    
    func updateProgressValue(progressValue: Float) {
        print("!!!! updateProgressValue called in bsscraper",progressValue)
        if let source = self.fetchRequestSource, source == .online || source == .manual {
            if let listener = self.scraperListener {
                listener.updateProgressValue(progressValue: progressValue)
            }
        }
    }
    
    func updateStepMessage(stepMessage: String) {
        //Do nothing
    }
    
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep) {
        //Do nothing
    }
    
    func updateSuccessType(successType: OrderFetchSuccessType) {
        //Do nothing
    }
    
    func onCompletion(isComplete: Bool) {
        if isComplete {
            self.stopScrapping()
            self.completionHandler((true, .fetchCompleted), nil)
        }
    }
    
    func onServicesDown(error: ASLException?) {
        stopScrapping()
        if let error = error {
            LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
            self.completionHandler((false, nil), error)
        } else {
            let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
            LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
            self.completionHandler((false, nil), error)
        }
    }
    
    func sendServicesDownCallback(error: ASLException?) {
        if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
            if let scrappingMode = scrappingMode, scrappingMode == .Foreground {
                onServicesDown(error: nil)
            }
        }
    }
    
    func updateScrapeProgressPercentage(value: Int) {
        //Do nothing
    }
    
    func updateProgressHeaderLabel(isUploadingPreviousOrder: Bool) {
        //Do nothing
    }
    
    private func updateProgressViewLabel(isUploadingPreviousOrder: Bool) {
        if let source = self.fetchRequestSource, source == .manual || source == .online {
            if let listener = self.scraperListener {
                listener.updateProgressHeaderLabel(isUploadingPreviousOrder: isUploadingPreviousOrder)
            }
        }
    }
}

extension BSScrapper: BSHtmlScrappingStatusListener {
   
    
    func onScrapeDataUploadCompleted(complete: Bool, error: ASLException?) {
        print("### onScrapeDataUploadCompleted ", complete)
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                              EventConstant.PanelistID: self.panelistID,
                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                              EventConstant.ScrappingType: ScrappingType.html.rawValue]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        
        if extractingOldOrders {
            self.scraperParams = nil
            self.bsHtmlScrapper = nil

            //For Walmart and Instacart update account state to Connected if all connection scrape orders uploaded
            updateAccountAsConnected(account: self.account)
            // Extract new orders on completing upload of pending orders
            self.extractNewOrders()
        } else {
            if complete {
                //For Walmart and Instacart update account state to Connected if all connection scrape orders uploaded
                updateAccountAsConnected(account: self.account)
                
                if let listener = self.scraperListener {
                    listener.updateProgressStep(htmlScrappingStep: .complete)
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepComplete, eventAttributes: logEventAttributes)
                }
                self.logEvent(status: EventState.success.rawValue,message:AppConstants.ScrappingCompleted)
                self.completionHandler((true, .fetchCompleted), nil)
                logEventAttributes[EventConstant.Status] = EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
            } else {
                self.logEvent(status: EventState.fail.rawValue,message: Strings.ErrorOrderExtractionFailed)
                self.completionHandler((false, nil), error!)
                logEventAttributes[EventConstant.Status] = EventStatus.Failure
                logEventAttributes[EventConstant.Reason] = Strings.ErrorOrderExtractionFailed
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
            }
            self.stopScrapping()
        }
    }
    
    func onHtmlScrappingSucess(response: String) {
        do {
            let jsonData = response.data(using: .utf8)!
            let scrapeResponse = try JSONDecoder().decode(JSCallback<[OrderDetails]>.self, from: jsonData)
            print("#### onHtmlScrappingSucess BSCrapper ", response)
            if scrapeResponse.type == "order\(ScrappingPage.details.rawValue)" {
                return
            }
            
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: self.orderSource.value,
                                                      EventConstant.PanelistID: self.panelistID,
                                                      EventConstant.OrderSourceID: self.account?.userID ?? "",
                                                      EventConstant.ScrappingStep: HtmlScrappingStep.listing.value,
                                                      EventConstant.ScrappingType: ScrappingType.html.rawValue]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            
            if scrapeResponse.type == "orderlist" {
                if scrapeResponse.status == "success" {
                    if let listener = self.scraperListener {
                        listener.updateProgressStep(htmlScrappingStep: .listing)
                        logEventAttributes[ EventConstant.Status] = EventStatus.Success
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepListScrappingSuccess, eventAttributes: logEventAttributes)
                    }
                    
                    let timerValue = self.timer.stop()
                    let listingScrapeTime = self.timer.stopTimer()
                    let message = "\(Strings.ScrappingPageListing) \(timerValue) + \(String(describing: scrapeResponse.data?.count))"
                    logEventAttributes [EventConstant.ScrappingTime] = message
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.onOrderListingCompletion, eventAttributes: logEventAttributes)
                    FirebaseAnalyticsUtil.logSentryMessage(message: message)
                    if let orderDetails = scrapeResponse.data, !orderDetails.isEmpty {
                        self.uploadOrderHistory(listingScrapeTime: listingScrapeTime, listingOrderCount: orderDetails.count, status: OrderStatus.InProgress.rawValue)
                        DispatchQueue.global().async { [self] in
                            insertOrderDetailsToDB(orderDetails: orderDetails) { dataInserted in
                                if dataInserted {
                                    updateProgressValue(progressValue: 50)
                                    self.didInsertToDB()
                                } else {
                                    self.stopScrapping()
                                    let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
                                    FirebaseAnalyticsUtil.logSentryError(error: error)
                                    self.completionHandler((false, nil), error)
                                }
                            }
                        }
                    } else {
                        if self.fetchRequestSource == .online || self.fetchRequestSource == .manual {
                            let dbOrderDetails = self.getOrderDetails()
                            if dbOrderDetails.count > 0 {
                                self.uploadOrderHistory(listingScrapeTime: listingScrapeTime, listingOrderCount: 0, status: OrderStatus.InProgress.rawValue)
                                updateProgressValue(progressValue: 50)
                                self.uploadPreviousOrders()
                            } else {
                                self.scrapingSuccessCallback(listingScrapeTime: listingScrapeTime)
                            }
                        } else {
                            self.scrapingSuccessCallback(listingScrapeTime: listingScrapeTime)
                        }
                    }

                    let userId = account!.userID
                    let amazonLogs = EventLogs(panelistId:self.panelistID , platformId: userId, section: getSectionType(), type: FailureTypes.none.rawValue, status: EventState.success.rawValue, message: AppConstants.msgOrderListSuccess, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrapingType: ScrappingType.html.rawValue, scrapingContext: getScrappingContext(),url: webClient.url?.absoluteString)
                    _ = AmazonService.logEvents(eventLogs: amazonLogs, orderSource: self.account!.source.value) { response, error in
                        self.sendServicesDownCallback(error: error)
                    }
                    logEventAttributes[EventConstant.Status] =  EventStatus.Success
                    logEventAttributes[EventConstant.Message] = message
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderListResultSuccess, eventAttributes: logEventAttributes)
                } else if scrapeResponse.status == "failed" {
                    let timerValue = self.timer.stop()
                    logEventAttributes [EventConstant.ScrappingTime] = timerValue
                    FirebaseAnalyticsUtil.logEvent(eventType: Strings.ScrappingPageListing, eventAttributes: logEventAttributes)
                    self.stopScrapping()
                    self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
                    
                    var error: String
                    if let errorReason = scrapeResponse.errorMessage {
                        error = errorReason
                    } else {
                        error = Strings.ErrorOrderExtractionFailed
                    }
                    let message = "\(Strings.ScrappingPageListing) + \(timerValue) + \(String(describing: scrapeResponse.data?.count)) + \(error) "
                    FirebaseAnalyticsUtil.logSentryMessage(message: message)
                    
                    let userId = account!.userID
                    let amazonLogs = EventLogs(panelistId: self.panelistID , platformId: userId, section: getSectionType(), type: FailureTypes.jsFailed.rawValue, status: EventState.fail.rawValue, message: error, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrapingType: ScrappingType.html.rawValue, scrapingContext: getScrappingContext(),url: webClient.url?.absoluteString)
                    _ = AmazonService.logEvents(eventLogs: amazonLogs, orderSource: self.orderSource.value) { response, error in
                        self.sendServicesDownCallback(error: error)
                    }
                    logEventAttributes[EventConstant.ErrorReason] =  error
                    logEventAttributes[EventConstant.Status] =  EventStatus.Failure
                    logEventAttributes[EventConstant.Message] =  message
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultFilure, eventAttributes: logEventAttributes)
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepListScrappingFailure, eventAttributes: logEventAttributes)
                }
            }
        } catch {
            let error = Strings.ErrorOrderExtractionFailed
            FirebaseAnalyticsUtil.logSentryMessage(message: error)
            self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.stopScrapping()
        let userId = account!.userID
        let eventLogs = EventLogs(panelistId: self.panelistID, platformId: userId, section: getSectionType() , type: error.errorEventLog!.rawValue, status: EventState.fail.rawValue, message: error.errorMessage, fromDate: self.dateRange?.fromDate ?? "", toDate: self.dateRange?.toDate ?? "", scrapingType: error.errorScrappingType?.rawValue, scrapingContext: getScrappingContext(),url: webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.orderSource.value) { response, error in
            self.sendServicesDownCallback(error: error)
        }
        self.completionHandler((false, nil), error)
        // API call
        
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: self.orderSource.value,
                                                  EventConstant.PanelistID: self.panelistID,
                                                  EventConstant.OrderSourceID: self.account?.userID ?? "",
                                                  EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                  EventConstant.EventName: EventType.HtmlScrapingFailed,
                                                  EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
    }
    
    func onScrapePageLoadData(pageLoadTime: Int64) {
        // DO nothing
    }
    
    func insertOrderDetailsToDB(orderDetails: [OrderDetails], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            var orderSectionType = ""
            let source = self.fetchRequestSource ?? .general
            if self.scrappingMode == .Foreground && source != .manual && source != .online {
                orderSectionType = SectionType.connection.rawValue
            } else {
                orderSectionType = SectionType.orderUpload.rawValue
            }
//            let sessionId = UUID().uuidString
            for orderDetail in orderDetails {
                orderDetail.userID = String(self.account!.userID)
                orderDetail.panelistID = String(self.account!.panelistID)
                orderDetail.orderSource = String(self.orderSource.value)
                orderDetail.startDate = self.dateRange?.fromDate
                orderDetail.endDate = self.dateRange?.toDate
                orderDetail.date = DateUtils.getDate(dateStr: orderDetail.orderDate)
                orderDetail.orderSectionType = orderSectionType
                orderDetail.uploadRetryCount = 0
                orderDetail.sessionID = self.sessionId
            }
            CoreDataManager.shared.insertOrderDetails(orderDetails: orderDetails) { status in
                DispatchQueue.main.async {
                    completion(true)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                          EventConstant.PanelistID: self.panelistID,
                                          EventConstant.OrderSourceID: self.account?.userID ?? "",
                                          EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                          EventConstant.Status: EventStatus.Success]
                    if let scrappingMode = self.scrappingMode {
                        logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                    }
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInsertScrappedOrderDetailsInDB, eventAttributes: logEventAttributes)
                }
            }
        }
    }
    
    func getOrderDetails() -> [OrderDetailsMO] {
        var orderDetails: [OrderDetailsMO] = []
        if let userID = self.account?.userID {
            orderDetails = CoreDataManager.shared.fetchOrderDetails(orderSource: self.orderSource.value, panelistID: self.panelistID, userID: userID)
            
        }
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                              EventConstant.PanelistID: self.panelistID,
                              EventConstant.OrderSourceID: account?.userID ?? "",
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrappedOrderDetailsFromDB, eventAttributes: logEventAttributes)
        
        return orderDetails
    }
    
    func getOrdersDetailsCountOnConnection(completion: @escaping (Int) -> Void) {
        var orderDetailsCount = 0
        ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { (configurations, error) in
            if let configuration = configurations {
                let orderUploadRetryCount = configuration.orderUploadRetryCount ?? AppConstants.orderUploadRetryCount
                if let toDate = self.dateRange?.toDate, let fromDate = self.dateRange?.fromDate {
                    orderDetailsCount = CoreDataManager.shared.getCountForOrderDetailsByOrderSection(orderSource: self.orderSource.value, panelistID: self.account!.panelistID, userID: self.account!.userID, orderSectionType: SectionType.connection.rawValue, orderUploadRetryCount: orderUploadRetryCount, endDate: toDate, startDate: fromDate)
                }
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                      EventConstant.PanelistID: self.panelistID,
                                      EventConstant.OrderSourceID: self.account?.userID ?? "",
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrappedOrderDetailsFromDB, eventAttributes: logEventAttributes)
                completion(orderDetailsCount)
            } else {
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    
                    logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                          EventConstant.PanelistID: self.panelistID,
                                          EventConstant.OrderSourceID: self.account?.userID ?? "",
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                let orderUploadRetryCount =  AppConstants.orderUploadRetryCount
                if let toDate = self.dateRange?.toDate, let fromDate = self.dateRange?.fromDate {
                    orderDetailsCount = CoreDataManager.shared.getCountForOrderDetailsByOrderSection(orderSource: self.orderSource.value, panelistID: self.account!.panelistID, userID: self.account!.userID, orderSectionType: SectionType.connection.rawValue, orderUploadRetryCount: orderUploadRetryCount, endDate: toDate, startDate: fromDate)
                }
                completion(orderDetailsCount)
            }
        }
    }
    
    private func didInsertToDB() {
        BSScriptFileManager.shared.getScriptForScrapping(orderSource: self.orderSource, scriptType: ScriptType.scrape.rawValue) { script in
            if let script = script {
                Utils.isListScrapping(isListScrapping:false)
                let orderDetails = OrderDetailsMapper.mapFromDBObject(dbOrderDetails: self.getOrderDetails())
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                      EventConstant.PanelistID: self.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderDetail, eventAttributes: logEventAttributes)
                let orders = self.removeDuplicateElements(orders: orderDetails)
                BSOrderDetailsScrapper(scrapperParams: self.getScraperParams()).scrapeOrderDetailPage(script: script, orderDetails: orders, mode: self.scrappingMode, source: self.fetchRequestSource, dateRange: self.dateRange, scraperListener: self.scraperListener, isNewSession: self.isNewSession, scrapingSessionStartedAt: self.getScrapeSessionTimer)
                print("### BSScrapper started scrapeOrderDetailPage")
                
            } else {
                self.stopScrapping()
                let error = ASLException(errorMessage: Strings.ErrorScriptNotFound, errorType: nil)
                self.completionHandler((false, nil), error)
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                      EventConstant.PanelistID: self.panelistID,
                                      EventConstant.OrderSourceID: self.account?.userID ?? "",
                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                      EventConstant.Status: EventStatus.Success]
                if let scrappingMode = self.scrappingMode {
                    logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                }
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileLoadingScrapingScript, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func removeDuplicateElements(orders: [OrderDetails]) -> [OrderDetails] {
        var uniqueOrders = [OrderDetails]()
        for order in orders {
            if !uniqueOrders.contains(where: {$0.orderId == order.orderId }) {
                uniqueOrders.append(order)
            }
        }
        return uniqueOrders
    }
    
    private func logEvent(status: String,message:String) {
        let eventLogs = EventLogs(panelistId: self.panelistID, platformId: self.account!.userID, section: getSectionType() , type: FailureTypes.none.rawValue, status: status, message: message, fromDate: self.dateRange?.fromDate ?? "", toDate: self.dateRange?.toDate ?? "", scrapingType: ScrappingType.html.rawValue, scrapingContext: self.getScrappingContext(),url: webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.orderSource.value) { response, error in
            self.sendServicesDownCallback(error: error)
        }
    }
    
    private func updateAccountAsConnected(account: Account?) {
        if let account = account {
            let source = account.source
            if source == .Walmart || source == .Instacart {
                print("!!! updateAccountAsConnected")
                self.getOrdersDetailsCountOnConnection() { orderDetailsUploadCount in
                    print("!!!! orderDetailsUploadCount",orderDetailsUploadCount)
                    let accountState = account.accountState
                    if (accountState == .ConnectionInProgress || accountState == .Connected) && orderDetailsUploadCount == 0 {
                        do {
                            try CoreDataManager.shared.updateUserAccount(userId: self.account!.userID, accountStatus: AccountState.Connected.rawValue, panelistId: self.panelistID, orderSource: self.account!.source.rawValue)
                        } catch let error {
                            print(AppConstants.tag, "updateAccountWithExceptionState", error.localizedDescription)
                        }
                        
                        let amazonId = self.account!.userID
                        _ = AmazonService.updateStatus(platformId: amazonId,
                                                       status: AccountState.Connected.rawValue,
                                                       message: AppConstants.msgConnected,
                                                       orderStatus: OrderStatus.Completed.rawValue, orderSource:  self.account!.source.value) { response, error in
                            self.sendServicesDownCallback(error: error)
                        }
                        self.account?.accountState = .Connected
                    }
                }
            }
        }
    }
    
    private func getScrappingContext()-> String{
        if (self.scrappingMode == .Foreground) {
            return ScrapingMode.Foreground.rawValue
        } else {
            return ScrapingMode.Background.rawValue
        }
    }
    
    private func getSectionType()-> String{
        if (self.scrappingMode == .Foreground) {
            return SectionType.connection.rawValue
        } else {
            return SectionType.orderUpload.rawValue
        }
    }
    
    private func getScrapingMode() -> String {
        if fetchRequestSource == .online {
            return ScrapingMode.Online.rawValue
        } else {
            return scrappingMode!.rawValue
        }
    }
    
    private func getscrapingSessionStatus(listingOrderCount: Int) -> String? {
        if fetchRequestSource == .online && isNewSession {
            if listingOrderCount == 0 {
                self.scrapingSessionEndedAt = DateUtils.getSessionTimer()
                return OrderStatus.Completed.rawValue
            } else {
                return OrderStatus.InProgress.rawValue
            }
        } else {
            return nil
        }
    }
    
    private func uploadOrderHistory(listingScrapeTime: Int64, listingOrderCount: Int, status: String) {
        if let fromDate = self.dateRange?.fromDate, let toDate = self.dateRange?.toDate, let userID = self.account?.userID {
            let orderRequest = OrderRequest(panelistId: self.panelistID, platformId: userID, fromDate: fromDate, toDate: toDate, status: status, data: [], listingScrapeTime: listingScrapeTime, listingOrderCount: listingOrderCount, scrapingSessionContext: getScrapingMode(), scrapingSessionStatus: getscrapingSessionStatus(listingOrderCount: listingOrderCount), scrapingSessionStartedAt: getScrapeSessionTimer,scrapingSessionEndedAt: self.scrapingSessionEndedAt,sessionId: self.sessionId)
            _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest, orderSource: self.orderSource.value) { response, error in
                DispatchQueue.global().async {
                    var logEventAttributes:[String:String] = [:]

                    logEventAttributes = [EventConstant.OrderSource:self.orderSource.value,
                                          EventConstant.PanelistID: self.panelistID,
                                          EventConstant.OrderSourceID: self.account?.userID ?? ""]
                    if let response = response {

                    } else {
                        logEventAttributes[EventConstant.Status] = EventStatus.Failure
                        let jsonString = String(describing: orderRequest)
                        if let error = error {
                            self.logPushEvent(message: error.error.debugDescription + " " + jsonString)
                            logEventAttributes[EventConstant.EventName] = EventType.UploadOrdersAPIFailed
                            FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                        } else {
                            self.logPushEvent(message: jsonString)
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.UploadOrdersAPIFailed, eventAttributes: logEventAttributes)
                        }
                    }
                }
            }
        }
    }
    
    private func logPushEvent(message:String){
        let eventLogs = EventLogs(panelistId: self.panelistID , platformId: account?.userID ?? "", section: SectionType.orderUpload.rawValue , type: FailureTypes.none.rawValue, status: EventState.fail.rawValue, message: message, fromDate: self.dateRange?.fromDate ?? "", toDate: self.dateRange?.toDate ?? "", scrapingType: ScrappingType.html.rawValue, scrapingContext: getScrapingMode(),url: "")
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.orderSource.value ) { response, error in}
    }
    
    
    private func scrapingSuccessCallback(listingScrapeTime: Int64) {
        // API call to back end
        self.stopScrapping()
        
        //For Walmart and Instacart update account state to Connected if all connection scrape orders uploaded
        updateAccountAsConnected(account: self.account)
        updateProgressValue(progressValue: 50)
        self.uploadOrderHistory(listingScrapeTime: listingScrapeTime, listingOrderCount: 0, status: OrderStatus.Completed.rawValue)
        if let listener = self.scraperListener {
            listener.updateProgressStep(htmlScrappingStep: .complete)
        }
        self.completionHandler((true, .fetchCompleted), nil)
    }
}
