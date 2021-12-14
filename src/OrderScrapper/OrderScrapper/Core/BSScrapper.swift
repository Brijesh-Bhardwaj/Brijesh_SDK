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

    private lazy var bsHtmlScrapper: BSHtmlScrapper = {
        return BSHtmlScrapper(params: self.scrapperParams)
    }()
    
    lazy var scrapperParams: BSHtmlScrapperParams = {
        let authenticator = try! self.getAuthenticator()
        
        return BSHtmlScrapperParams(webClient: self.webClient, webNavigationDelegate: self.webClientDelegate, listener: self, authenticator: authenticator, configuration: self.configuration, account: self.account!, scrappingType: self.scrappingType, scrappingMode: scrappingMode?.rawValue)
    }()
    
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
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: self.account!.source.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
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
        logEventAttributes = [EventConstant.OrderSource: self.account!.source.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
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
        extractingOldOrders = true
        ConfigManager.shared.getConfigurations(orderSource: self.orderSource) { (configuration, error) in
            if let configuration = configuration {
                self.configuration = configuration
                self.didInsertToDB()
            } else {
                self.stopScrapping()
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                          EventConstant.PanelistID: self.account!.panelistID,
                                          EventConstant.OrderSourceID: self.account!.userID,
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
        extractingOldOrders = false

        if let listener = self.scraperListener {
            listener.updateProgressStep(htmlScrappingStep: .startScrapping)
            var logEventAttributes:[String:String] = [:]

            logEventAttributes = [EventConstant.OrderSource:self.account!.source.value,
                                  EventConstant.PanelistID: self.account!.panelistID,
                                  EventConstant.OrderSourceID: self.account!.userID,
                                  EventConstant.ScrappingStep: HtmlScrappingStep.startScrapping.value,
                                  EventConstant.Status: EventStatus.Success]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepStarHtmlScrapping, eventAttributes: logEventAttributes)
        }
        _ = AmazonService.getDateRange(platformId: self.account!.userID, orderSource: self.orderSource.value) { response, error in
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

                logEventAttributes = [EventConstant.OrderSource: self.account!.source.value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.ScrappingStep: HtmlScrappingStep.startScrapping.value,
                                      EventConstant.Data: json,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            } else {
                var logEventAttributes:[String:String] = [:]

                logEventAttributes = [EventConstant.OrderSource:self.account!.source.value,
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
                        logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                              EventConstant.PanelistID: self.account!.panelistID,
                                              EventConstant.OrderSourceID: self.account!.userID,
                                              EventConstant.ScrappingType: dateRange.scrappingType!,
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
            logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                  EventConstant.PanelistID: self.account!.panelistID,
                                  EventConstant.OrderSourceID: self.account!.userID,
                                  EventConstant.ScrappingType: dateRange.scrappingType!,
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
        BSScriptFileManager.shared.getScriptForScrapping(orderSource: self.orderSource) { script in
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
                                                  , timerHandler: timerHandler, param: self.scrapperParams)
                } else {
                    self.bsHtmlScrapper.extractOrders(script: executableScript, url: self.configuration.listing)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                          EventConstant.PanelistID: self.account!.panelistID,
                                          EventConstant.OrderSourceID: self.account!.userID,
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
                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
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
        let eventLogs = EventLogs(panelistId: panelistID, platformId:platformId, section: SectionType.orderUpload.rawValue, type: FailureTypes.timeout.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: self.dateRange?.fromDate, toDate: self.dateRange?.toDate, scrapingType: ScrappingType.report.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: orderSource) { response, error in
            
        }
        let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource:  self.orderSource.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingType: ScrappingType.html.rawValue,
                              EventConstant.EventName: EventType.TimeoutOccurred,
                              EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        
        self.completionHandler((false, nil), error)
    }
    
    func onWebviewError(isError: Bool) {
        if isError {
            self.stopScrapping()
            let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
            self.completionHandler((false, nil), error)
        }
    }
    
    func updateProgressValue(progressValue: Float) {
        //Do nothing
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
}

extension BSScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool, error: ASLException?) {
        print("### onScrapeDataUploadCompleted ", complete)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource:  self.orderSource.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingType: ScrappingType.html.rawValue]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        
        if extractingOldOrders {
            self.extractNewOrders()
        } else {
            if complete {
                if let listener = self.scraperListener {
                    listener.updateProgressStep(htmlScrappingStep: .complete)
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepComplete, eventAttributes: logEventAttributes)
                }
                self.logEvent(status: EventState.success.rawValue)
                self.completionHandler((true, .fetchCompleted), nil)
                logEventAttributes[EventConstant.Status] = EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIUploadOrderDetails, eventAttributes: logEventAttributes)
            } else {
                self.logEvent(status: EventState.fail.rawValue)
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
        do {
            let scrapeResponse = try JSONDecoder().decode(JSCallback<[OrderDetails]>.self, from: jsonData)
            print("#### onHtmlScrappingSucess BSCrapper ", response)
            if scrapeResponse.type == "order\(ScrappingPage.details.rawValue)" {
                return
            }
            
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: self.orderSource.value,
                                                      EventConstant.PanelistID: self.account!.panelistID,
                                                      EventConstant.OrderSourceID: self.account!.userID,
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
                    let message = "\(timerValue) + \(String(describing: scrapeResponse.data?.count))"
                    logEventAttributes [EventConstant.ScrappingTime] = message
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.onOrderListingCompletion, eventAttributes: logEventAttributes)
                    FirebaseAnalyticsUtil.logSentryMessage(message: message)
                    if let orderDetails = scrapeResponse.data, !orderDetails.isEmpty {
                        insertOrderDetailsToDB(orderDetails: orderDetails) { dataInserted in
                            if dataInserted {
                                self.didInsertToDB()
                            } else {
                                self.stopScrapping()
                                let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
                                FirebaseAnalyticsUtil.logSentryError(error: error)
                                self.completionHandler((false, nil), error)
                            }
                        }
                    } else {
                        self.stopScrapping()
                        if let listener = self.scraperListener {
                            listener.updateProgressStep(htmlScrappingStep: .complete)
                        }
                        self.completionHandler((true, .fetchCompleted), nil)
                    }
                    let amazonLogs = EventLogs(panelistId:account!.panelistID , platformId: account!.userID, section: SectionType.orderUpload.rawValue, type: FailureTypes.none.rawValue, status: EventState.success.rawValue, message: AppConstants.msgOrderListSuccess, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
                    _ = AmazonService.logEvents(eventLogs: amazonLogs, orderSource: self.account!.source.value) { response, error in
                        
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
                    
                    let panelistId = account!.panelistID
                    let userId = account!.userID
                    let amazonLogs = EventLogs(panelistId: panelistId , platformId: userId, section: SectionType.orderUpload.rawValue, type: FailureTypes.jsFailed.rawValue, status: EventState.fail.rawValue, message: error, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
                    _ = AmazonService.logEvents(eventLogs: amazonLogs, orderSource: self.account!.source.value) { response, error in
                        
                    }
                    logEventAttributes[EventConstant.ErrorReason] =  error
                    logEventAttributes[EventConstant.Status] =  EventStatus.Failure
                    logEventAttributes = [EventConstant.Message: message]
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
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: SectionType.orderUpload.rawValue , type: error.errorEventLog!.rawValue, status: EventState.fail.rawValue, message: error.errorMessage, fromDate: self.dateRange?.fromDate!, toDate: self.dateRange?.toDate!, scrapingType: error.errorScrappingType?.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.account!.source.value) { response, error in
                //TODO
        }
        self.completionHandler((false, nil), error)
        // API call
       
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: self.orderSource.value,
                                                  EventConstant.PanelistID: self.account!.panelistID,
                                                  EventConstant.OrderSourceID: self.account!.userID,
                                                  EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                  EventConstant.EventName: EventType.HtmlScrapingFailed,
                                                  EventConstant.Status: EventStatus.Failure]
        if let scrappingMode = self.scrappingMode {
            logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
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
                
                BSOrderDetailsScrapper(scrapperParams: self.scrapperParams).scrapeOrderDetailPage(script: script, orderDetails: orderDetails, mode: self.scrappingMode, source: self.fetchRequestSource)
                print("### BSScrapper started scrapeOrderDetailPage")
                
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), nil)
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                      EventConstant.PanelistID: self.account!.panelistID,
                                      EventConstant.OrderSourceID: self.account!.userID,
                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                      EventConstant.Status: EventStatus.Success]
                if let scrappingMode = self.scrappingMode {
                    logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                }
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileLoadingScrapingScript, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func logEvent(status: String) {
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: SectionType.orderUpload.rawValue , type: FailureTypes.none.rawValue, status: status, message: AppConstants.bgScrappingCompleted, fromDate: self.dateRange?.fromDate!, toDate: self.dateRange?.toDate!, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.account!.source.value) { response, error in
                //TODO
        }
    }
}


