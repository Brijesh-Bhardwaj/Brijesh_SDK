//  BSScrapper.swift
//  OrderScrapper

import Foundation
import Sentry

public enum HtmlScrappingStep: Int16 {
    case startScrapping = 1,
         listing = 2,
         complete = 3
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
    var scrappingType: String!
    public var scraperListener: ScraperProgressListener?
    public var scrappingMode: ScrapingMode?
    
    lazy var scrapperParams: BSHtmlScrapperParams = {
        let authenticator = try! self.getAuthenticator()
        
        return BSHtmlScrapperParams(webClient: self.webClient, webNavigationDelegate: self.webClientDelegate, listener: self, authenticator: authenticator, configuration: self.configuration, account: self.account!, scrappingType: self.scrappingType)
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
        SentrySDK.capture(error: error)
        throw error
    }
    
    func getOrderSource() throws -> OrderSource {
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        SentrySDK.capture(error: error)
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
                let error = ASLException(
                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                self.completionHandler((false, nil), error)
                SentrySDK.capture(error: error)
                
                
            }
        }
    }
    
    private func extractNewOrders() {
        extractingOldOrders = false
        if let listener = self.scraperListener {
            listener.updateProgressStep(htmlScrappingStep: .startScrapping)
        }
        _ = AmazonService.getDateRange(amazonId: self.account!.userID){ response, error in
            if let dateRange = response {
                self.didReceive(dateRange: dateRange)
            } else {
                self.stopScrapping()
                let error = ASLException(
                    errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
                SentrySDK.capture(error: error)
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
                    let error = ASLException(
                        errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                    SentrySDK.capture(error: error)
                    self.completionHandler((false, nil), error)
                }
            }
        } else {
            self.stopScrapping()
            let error =  ASLException(
                errorMessage: Strings.ErrorFetchSkipped, errorType: nil)
            SentrySDK.capture(error: error)
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
                                                orderId: nil)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptBuilder)
                
                if self.dateRange?.scrappingType == ScrappingType.report.rawValue {
                    let timerHandler = TimerHandler(timerCallback: self)
                    self.CSVScrapper.scrapeOrders(response: self.dateRange!, account: self.account!
                                                  , timerHandler: timerHandler, param: self.scrapperParams)
                } else {
                    BSHtmlScrapper(params: self.scrapperParams)
                        .extractOrders(script: executableScript, url: self.configuration.listing)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: try! self.getOrderSource().value,
                                          EventConstant.PanelistID: self.account!.panelistID,
                                          EventConstant.OrderSourceID: self.account!.userID,
                                          EventConstant.Status: EventStatus.Success]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgInjectJSForOrderListing, eventAttributes: logEventAttributes)
                }
            } else {
                self.stopScrapping()
                let error = ASLException(
                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil)
                SentrySDK.capture(error: error)
                self.completionHandler((false, nil), error)
            }
        }
    }
    
    func onTimerTriggered(action: String) {
        self.stopScrapping()
        let panelistID = self.account?.panelistID ?? ""
        let platformId = self.account?.userID ?? ""
        let eventLogs = EventLogs(panelistId: panelistID, platformId:platformId, section: SectionType.orderUpload.rawValue, type: FailureTypes.timeout.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: self.dateRange?.fromDate, toDate: self.dateRange?.toDate, scrappingType: ScrappingType.report.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs) { response, error in
            
        }
        let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
        SentrySDK.capture(error: error)
        self.completionHandler((false, nil), error)
    }
    
    func onWebviewError(isError: Bool) {
        if isError {
            self.stopScrapping()
            let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
            SentrySDK.capture(error: error)
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
                              EventConstant.OrderSourceID: self.account!.userID]
        if extractingOldOrders {
            self.extractNewOrders()
        } else {
            if complete {
                if let listener = self.scraperListener {
                    listener.updateProgressStep(htmlScrappingStep: .complete)
                }
                self.logEvent()
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
                if let listener = self.scraperListener {
                    listener.updateProgressStep(htmlScrappingStep: .listing)
                }
                
                let timerValue = self.timer.stop()
                let message = "\(Strings.ScrappingPageListing) + \(timerValue) + \(String(describing: scrapeResponse?.data?.count))"
                SentrySDK.capture(message: message)
                if let orderDetails = scrapeResponse?.data, !orderDetails.isEmpty {
                    insertOrderDetailsToDB(orderDetails: orderDetails) { dataInserted in
                        if dataInserted {
                            self.didInsertToDB()
                        } else {
                            self.stopScrapping()
                            let error = ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil)
                            SentrySDK.capture(error: error)
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
                let amazonLogs = EventLogs(panelistId:account!.panelistID , platformId: account!.userID, section: SectionType.orderUpload.rawValue, type: FailureTypes.none.rawValue, status: EventState.success.rawValue, message: AppConstants.msgOrderListSuccess, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrappingType: ScrappingType.html.rawValue)
                _ = AmazonService.logEvents(eventLogs: amazonLogs) { response, error in
                    
                }
                logEventAttributes[EventConstant.Status] =  EventStatus.Success
                logEventAttributes[EventConstant.Message] = message
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderListResultSuccess, eventAttributes: logEventAttributes)
            } else if scrapeResponse?.status == "failed" {
                let timerValue = self.timer.stop()
                self.stopScrapping()
                self.completionHandler((false, nil), ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
                
                var error: String
                if let errorReason = scrapeResponse?.errorMessage {
                    error = errorReason
                } else {
                    error = Strings.ErrorOrderExtractionFailed
                }
                
                let message = "\(Strings.ScrappingPageListing) + \(timerValue) + \(String(describing: scrapeResponse?.data?.count)) + \(error) "
                SentrySDK.capture(message: message)
              
                let panelistId = account!.panelistID
                let userId = account!.userID
                let amazonLogs = EventLogs(panelistId: panelistId , platformId: userId, section: SectionType.orderUpload.rawValue, type: FailureTypes.jsFailed.rawValue, status: EventState.fail.rawValue, message: error, fromDate: dateRange?.fromDate, toDate: dateRange?.toDate, scrappingType: ScrappingType.html.rawValue)
                _ = AmazonService.logEvents(eventLogs: amazonLogs) { response, error in
                    
                }
                logEventAttributes[EventConstant.ErrorReason] =  error
                logEventAttributes[EventConstant.Status] =  EventStatus.Failure
                logEventAttributes = [EventConstant.Message: message]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultFilure, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        self.stopScrapping()
        SentrySDK.capture(error: error)
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: SectionType.orderUpload.rawValue , type: error.errorEventLog!.rawValue, status: EventState.fail.rawValue, message: error.errorMessage, fromDate: self.dateRange?.fromDate!, toDate: self.dateRange?.toDate!, scrappingType: error.errorScrappingType?.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs) { response, error in
                //TODO
        }
        self.completionHandler((false, nil), error)
        // API call
       
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
                
                BSOrderDetailsScrapper(scrapperParams: self.scrapperParams).scrapeOrderDetailPage(script: script, orderDetails: orderDetails, mode: self.scrappingMode)
                print("### BSScrapper started scrapeOrderDetailPage")
                
            } else {
                self.stopScrapping()
                self.completionHandler((false, nil), nil)
            }
        }
    }
    
    private func logEvent() {
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: SectionType.orderUpload.rawValue , type: FailureTypes.none.rawValue, status: EventState.success.rawValue, message: AppConstants.bgScrappingCompleted, fromDate: self.dateRange?.fromDate!, toDate: self.dateRange?.toDate!, scrappingType: ScrappingType.html.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs) { response, error in
                //TODO
        }
    }
}

