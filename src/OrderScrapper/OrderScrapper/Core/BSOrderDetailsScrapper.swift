//  BSOrderDetailsScrapper.swift
//  OrderScrapper

import Foundation
import Sentry

class BSOrderDetailsScrapper {
    let params: BSHtmlScrapperParams
    var script: String!
    var queue: Queue<OrderDetails>!
    var orderDetail: OrderDetails!
    var timer = BSTimer()
    var scrappingMode: ScrapingMode?
    var oneOrderScrape: Bool = false
    var fetchRequestSource: FetchRequestSource?
    var orderDetailsTimer = BSTimer()
    var orderDetailsCount = 0
    var dateRange: DateRange?
    var scraperListener: ScraperProgressListener?
    var totalOrderCount: Int = 0
    var scrapeTime: [String: Any] = [:]
    var isNewSession = false
    var isScrapingComplete = false
    let lock = NSLock()
    var scrapingSessionStartedAt: String? = nil
    var batchList: [Dictionary<String,Any>] = []
    var bactchProcessCount: Int = 0
    var currentBatchDateRange:DateRange? = nil
    var scrapingSessionEndedAt: String? = nil
    
    lazy var scrapeQueue: [String] = {
        return Array<String>()
    }()
    
    lazy var dataUploader: BSDataUploader = {
        return BSDataUploader(listener: self)
    }()
    
    lazy var htmlScrapper: BSHtmlScrapper = {
        return BSHtmlScrapper(params: self.scrapperParams)
    }()
    
    lazy var scrapperParams: BSHtmlScrapperParams = {
        return BSHtmlScrapperParams(webClient: self.params.webClient, webNavigationDelegate: self.params.webNavigationDelegate, listener: self, authenticator: self.params.authenticator, configuration: self.params.configuration, account: self.params.account, scrappingType: nil, scrappingMode: scrappingMode?.rawValue)
    }()
    
    init(scrapperParams: BSHtmlScrapperParams) {
        self.params = scrapperParams
    }
    
    func scrapeOrderDetailPage(script: String, orderDetails: [OrderDetails], mode: ScrapingMode?,
                               source: FetchRequestSource?, dateRange: DateRange?, scraperListener: ScraperProgressListener?, isNewSession: Bool, scrapingSessionStartedAt: String?) {
        orderDetailsTimer.start()
        self.script = script
        self.queue = Queue(queue: orderDetails)
        self.fetchRequestSource = source
        if fetchRequestSource == .online {
            self.scrappingMode = .Online
        } else {
            self.scrappingMode = mode
        }
        self.dateRange = dateRange
        self.scraperListener = scraperListener
        self.totalOrderCount = orderDetails.count
        self.isNewSession = isNewSession
        self.scrapingSessionStartedAt = scrapingSessionStartedAt
        self.scrapingSessionEndedAt = nil
        scrapeOrder()
    }
    
    private func scrapeOrder() {
        orderDetail = queue.peek()
        if orderDetail != nil {
            if queue!.isEmpty() {
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                      EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                      EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                      EventConstant.Status: EventStatus.Success]
                if let scrappingMode = scrappingMode {
                    logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                }
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultSuccess, eventAttributes: logEventAttributes)
            }
            
            if let script = script, let detailUrl = orderDetail?.detailsUrl {
                //Param for order detail page scrapping
                timer.start()
                // TODO :- check the orderDate as it optional value
                let scriptParam = ScriptParam(script: script, dateRange: nil, url: detailUrl, scrappingPage: .details, urls: nil, orderId: orderDetail.orderId, orderDate: orderDetail.orderDate)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
                self.scrapeQueue.append(orderDetail.orderId)
                self.htmlScrapper.extractOrders(script: executableScript, url: detailUrl)
            }
        } else {
            onDataUploadComplete()
        }
    }
    
    private func scrapeOrder(orderDetail: OrderDetails) {
        if queue!.isEmpty() {
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                  EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                  EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                  EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                  EventConstant.Status: EventStatus.Success]
            if let scrappingMode = scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultSuccess, eventAttributes: logEventAttributes)
        }
        
        if let script = script {
            let detailUrl = orderDetail.detailsUrl
            //Param for order detail page scrapping
            timer.start()
            // TODO :- check the orderDate as it optional value
            let scriptParam = ScriptParam(script: script, dateRange: nil, url: detailUrl, scrappingPage: .details, urls: nil, orderId: orderDetail.orderId, orderDate: orderDetail.orderDate)
            let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
            self.scrapeQueue.append(orderDetail.orderId)
            self.htmlScrapper.extractOrders(script: executableScript, url: detailUrl)
        }
    }
    
    private func uploadScrapeData(data: [Dictionary<String, Any>]) {
        if !queue.isEmpty() {
            print("$$$$ scrapeQueue",OrderState.InProgress.rawValue)
            if let orderDetail = orderDetail {
                self.dataUploader.addData(data: data, orderDetail: orderDetail, orderState: OrderState.InProgress.rawValue, scrapingContext: self.scrappingMode!.rawValue, scrapingSessionStatus: self.getScrapingSessionStatus(), scrapingSessionStartedAt: self.scrapingSessionStartedAt,scrapingSessionEndeddAt: nil)
            }
        } else {
            self.getOrdersDetailsCountOnConnection { [weak self] orderDetailsUploadCount in
                guard let self = self else {return}
                if orderDetailsUploadCount <= self.batchList.count {
                    self.batchList = []
                    if let orderDetail = self.orderDetail {
                        print("$$$$ scrapeQueue",OrderState.Completed.rawValue)
                        self.dataUploader.addData(data: data, orderDetail: orderDetail,orderState: OrderState.Completed.rawValue, scrapingContext: self.scrappingMode!.rawValue, scrapingSessionStatus: self.getScrapingSessionStatus(), scrapingSessionStartedAt: self.scrapingSessionStartedAt,scrapingSessionEndeddAt: self.getScrapingEndSessionTimer())
                    }
                } else {
                    if let orderDetail = self.orderDetail {
                        print("$$$$ scrapeQueue",OrderState.InProgress.rawValue)
                        self.dataUploader.addData(data: data, orderDetail: orderDetail, orderState: OrderState.InProgress.rawValue, scrapingContext: self.scrappingMode!.rawValue, scrapingSessionStatus: self.getScrapingSessionStatus(), scrapingSessionStartedAt: self.scrapingSessionStartedAt,scrapingSessionEndeddAt: self.getScrapingEndSessionTimer())
                    }
                }
            }
        }
    }
    
    private func getScrapingSessionStatus() -> String? {
        if fetchRequestSource == .online && isNewSession {
            if !queue.isEmpty() {
                return OrderStatus.InProgress.rawValue
            } else {
                self.scrapingSessionEndedAt = DateUtils.getSessionTimer()
                return OrderStatus.Completed.rawValue
            }
        } else {
            return nil
        }
    }
    
    private func getScrapingEndSessionTimer() -> String? {
        if fetchRequestSource == .online || fetchRequestSource == .manual {
            return  DateUtils.getSessionTimer()
        } else {
            return nil
        }
    }
    
    private func scrapeNextOrder() {
        if !self.scrapeQueue.isEmpty {
            self.scrapeQueue.remove(at: 0)
        }
        
        let shouldScrape = self.shouldScrapeNextOrder()
        if shouldScrape {
            //Show scrape percentage for manual scraping
            showScrapePercentage(dataUploadComplete: false)
            
            ConfigManager.shared.getConfigurations(orderSource: self.params.account.source) { (configurations, error) in
                if let configuration = configurations {
                    let orderDetailDelay = configuration.orderDetailDelay ?? 1
                    print("##### orderDetailDelay",orderDetailDelay)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(orderDetailDelay)) { [weak self] in
                        guard let self = self else { return }
                        self.scrapeOrder()
                    }
                } else {
                    if let error = error {
                        var logEventAttributes:[String:String] = [:]
                        
                        logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                              EventConstant.PanelistID: self.params.account.panelistID,
                                              EventConstant.OrderSourceID: self.params.account.userID,
                                              EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                              EventConstant.Status: EventStatus.Failure]
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                        guard let self = self else { return }
                        self.scrapeOrder()
                    }
                }
            }
        } else {
            self.queue.resetQueue()
            self.onDataUploadComplete()
        }
    }
    
    private func shouldScrapeNextOrder() -> Bool {
        if let mode = self.scrappingMode, mode == .Foreground {
            if let source = self.fetchRequestSource, source == .manual || source == .online {
                return true
            } else {
                return false
            }
        }
        return true
    }
    
    func getOrdersDetailsCountOnConnection(completion: @escaping (Int) -> Void) {
        var orderDetailsCount = 0
        let orderSource = self.params.account.source
        ConfigManager.shared.getConfigurations(orderSource: orderSource) { (configurations, error) in
            if let configuration = configurations {
                let orderUploadRetryCount = configuration.orderUploadRetryCount ?? AppConstants.orderUploadRetryCount
                if let toDate = self.orderDetail?.endDate, let fromDate = self.orderDetail?.startDate ,let sectionType = self.orderDetail?.orderSectionType{
                    orderDetailsCount = CoreDataManager.shared.getCountForOrderDetailsByOrderSection(orderSource: orderSource.value, panelistID: self.params.account.panelistID, userID: self.params.account.userID, orderSectionType: sectionType, orderUploadRetryCount: orderUploadRetryCount, endDate: toDate, startDate: fromDate)
                }
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                      EventConstant.PanelistID: self.params.account.panelistID,
                                      EventConstant.OrderSourceID: self.params.account.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgRetrieveScrappedOrderDetailsFromDB, eventAttributes: logEventAttributes)
                completion(orderDetailsCount)
            } else {
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    
                    logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                          EventConstant.PanelistID: self.params.account.panelistID,
                                          EventConstant.OrderSourceID: self.params.account.userID,
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                let orderUploadRetryCount =  AppConstants.orderUploadRetryCount
                if let toDate = self.dateRange?.toDate, let fromDate = self.dateRange?.fromDate {
                    orderDetailsCount = CoreDataManager.shared.getCountForOrderDetailsByOrderSection(orderSource: orderSource.value, panelistID: self.params.account.panelistID, userID: self.params.account.userID, orderSectionType: SectionType.connection.rawValue, orderUploadRetryCount: orderUploadRetryCount, endDate: toDate, startDate: fromDate)
                }
                completion(orderDetailsCount)
            }
        }
    }
    
    private func calculateScrapePercentage() -> Int {
        if totalOrderCount > 0 {
            let scrapeCount = totalOrderCount - queue.dataQueue.count
            let scrapePercentage = (Float(scrapeCount)/Float(totalOrderCount))*100
            print("############# TotalOrder-> \(totalOrderCount)  ScrapeCount- \(scrapeCount)  calculateScrapePercentage  \(Int(round(scrapePercentage))) %")
            return Int(round(scrapePercentage))
        }
        return 0
    }
    
    private func showScrapePercentage(dataUploadComplete: Bool) {
        if let source = self.fetchRequestSource, source == .manual || source == .online {
            if let listener = self.scraperListener {
                let value = calculateScrapePercentage()
                if value > 0 {
                    if dataUploadComplete {
                        listener.updateScrapeProgressPercentage(value: value)
                    } else if value < 100 {
                        listener.updateScrapeProgressPercentage(value: value)
                    }
                }
            }
        }
    }
    
    private func getBatchCount(completionHandler: @escaping(Int) -> Void) {
        let orderSource = self.params.account.source
        ConfigManager.shared.getConfigurations(orderSource: orderSource) { (configurations, error) in
            if let configuration = configurations {
                let uploadBatchSize = configuration.uploadBatchSize ?? AppConstants.uploadBatchSize
                
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                      EventConstant.PanelistID: self.params.account.panelistID,
                                      EventConstant.OrderSourceID: self.params.account.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrppingBatchSizeFailure, eventAttributes: logEventAttributes)
                completionHandler(uploadBatchSize)
            } else {
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    
                    logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                          EventConstant.PanelistID: self.params.account.panelistID,
                                          EventConstant.OrderSourceID: self.params.account.userID,
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                let uploadBatchSize = AppConstants.uploadBatchSize
                completionHandler(uploadBatchSize)
            }
            
        }
    }
}

extension BSOrderDetailsScrapper: BSHtmlScrappingStatusListener {
    func onScrapePageLoadData(pageLoadTime: Int64) {
        scrapeTime[Strings.PageLoadTime] = pageLoadTime
    }
    
    func onScrapeDataUploadCompleted(complete: Bool, error: ASLException?) {
        //NA
    }
    
    func onHtmlScrappingSucess(response: String) {
        LibContext.shared.timeoutType = TimeoutTypes.timeoutOrderDetail.rawValue
        let jsonData = response.data(using: .utf8)!
        let object = try? JSONSerialization.jsonObject(with: jsonData, options: [])
        
        if let jsCallBackResult = object as? Dictionary<String,Any?> {
            if let type  = jsCallBackResult["type"] as? String {
                if type == "orderdetails" {
                    if let status = jsCallBackResult["status"] as? String {
                        if status == "success" {
                            let timerValue = self.timer.stop()
                            let scrapingTime = self.timer.stopTimer()
                            orderDetailsCount = orderDetailsCount + 1
                            let message = "\(Strings.ScrappingPageDetails)\(timerValue) \(orderDetailsCount)"
                            let orderDataCount = jsCallBackResult["data"] as? Dictionary<String,Any>
                            FirebaseAnalyticsUtil.logSentryMessage(message: message)
                            var logEventAttributes = [EventConstant.Message: message, EventConstant.OrderSource: orderDetail.orderSource ?? "", EventConstant.Status: EventStatus.Success, EventConstant.ScrappingType: ScrappingType.html.rawValue]
                            if let scrappingMode = scrappingMode {
                                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                            }
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.onSingleOrderDetailScrape, eventAttributes: logEventAttributes)
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultSuccess, eventAttributes: logEventAttributes)
                            scrapeTime[Strings.ScrapeTime] = scrapingTime
                            scrapeTime[Strings.scrapingMode] = scrappingMode?.rawValue
                            print("### onHtmlScrappingSucess for OrderDetail", response)
                            if var orderDetails = jsCallBackResult["data"] as? Dictionary<String,Any> {
                                orderDetails[Strings.ScrapingTime] = scrapeTime
                                if fetchRequestSource == .online || fetchRequestSource == .manual || scrappingMode == .Background {
                                    self.handleBatchProcess(data: orderDetails)
                                }else{
                                    self.uploadScrapeData(data: [orderDetails])
                                }
                            }
                            self.scrapeNextOrder()
                            //TODO Check
                        } else if status == "failed" {
                            let timerValue = self.timer.stop()
                            let message = "\(Strings.ScrappingPageListing) + \(timerValue) "
                            
                            //Update upload retry count in order details
                            updateUploadRetryCount(orderDetails: orderDetail)
                            
                            //Scrape next order
                            self.scrapeNextOrder()
                            FirebaseAnalyticsUtil.logSentryMessage(message: message)
                            
                            var error: String
                            if let errorReason = jsCallBackResult["errorMessage"] as? String {
                                error = errorReason
                            } else {
                                error = Strings.ErrorOrderExtractionFailed
                            }
                            let errorMessage = ASLException(errorMessage: error, errorType: .none )
                            if let scrappingMode = self.scrappingMode {
                                logPushEvent(error: errorMessage,scrappingMode:scrappingMode.rawValue)
                            }
                            var logEventAttributes:[String:String] = [:]
                            logEventAttributes = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                                  EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                                  EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                                  EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                  EventConstant.ErrorReason: error,
                                                  EventConstant.Status: EventStatus.Failure, EventConstant.Message: message]
                            if let scrappingMode = scrappingMode {
                                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                            }
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.onSingleOrderDetailScrapeFilure, eventAttributes: logEventAttributes)
                            FirebaseAnalyticsUtil.logEvent(eventType: Strings.ScrappingPageDetails, eventAttributes: logEventAttributes)
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultFilure, eventAttributes: logEventAttributes)
                        }
                    }
                }
            }
        }
    }
    
    func handleBatchProcess(data: Dictionary<String, Any>){
        let dateRange = DateRange(fromDate: orderDetail.startDate, toDate: orderDetail.endDate, enableScraping: true, lastOrderId: nil, scrappingType: nil, showNotification: false)
        
        //Set the current batch date range
        if(batchList.count == 0){
            currentBatchDateRange = DateRange(fromDate: orderDetail.startDate, toDate: orderDetail.endDate, enableScraping: true, lastOrderId: nil, scrappingType: nil, showNotification: false)
        }
        //If the current date range and batch date range are equal means do the action
        if(dateRange.fromDate == currentBatchDateRange?.fromDate && dateRange.toDate == currentBatchDateRange?.toDate ){
            //If batch list count is less than configuration count means append the data into list
            
            //TODO:- Do we need to optimize getting the batch size once for a ordersource
            self.getBatchCount() { response in
                print("#### batch count",response)
                if (self.batchList.count <= response ) {
                    self.batchList.append(data)
                } else {
                    //If batch list count is greater than configuration count means upload the batch and add the next item into batch list
                    self.uploadScrapeData(data: self.batchList)
                    self.batchList = []
                    self.currentBatchDateRange = DateRange(fromDate: self.orderDetail.startDate, toDate: self.orderDetail.endDate, enableScraping: true, lastOrderId: nil, scrappingType: nil, showNotification: false)
                    self.batchList.append(data)
                }
                
                //If queue is empty means upload the batch and clear the batch list
                if(self.queue.isEmpty()){
                    self.uploadScrapeData(data: self.batchList)
                }
            }
        } else {
            //If date range is not same means upload the current batch and clear the batch list.
            self.uploadScrapeData(data: batchList)
            batchList = []
            
            //If queue is empty means upload the batch.
            if queue.isEmpty(){
                batchList.append(data)
                self.uploadScrapeData(data: batchList)
            }else{
                //If queue is not empty means append the data into batch list
                currentBatchDateRange = DateRange(fromDate: orderDetail.startDate, toDate: orderDetail.endDate, enableScraping: true, lastOrderId: nil, scrappingType: nil, showNotification: false)
                batchList.append(data)
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        print("### onHtmlScrappingFailure ")
        LibContext.shared.timeoutType = TimeoutTypes.timeoutOrderDetail.rawValue
        if error.errorType == .multiAuthError {
            WebCacheCleaner.clear(completionHandler: nil)
            self.params.listener.onHtmlScrappingFailure(error: error)
            if let scrappingMode = self.scrappingMode {
                logPushEvent(error:error,scrappingMode:scrappingMode.rawValue)
            }
        } else if error.errorType == ErrorType.authError || error.errorType == ErrorType.authChallenge {
            self.params.listener.onScrapeDataUploadCompleted(complete: false, error: error)
            
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                                      EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                                      EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                      EventConstant.EventName: EventType.HtmlScrapingFailed,
                                                      EventConstant.Status: EventStatus.Failure]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                logPushEvent(error:error,scrappingMode:scrappingMode.rawValue)
            }
            FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        } else {
            if let scrappingMode = self.scrappingMode {
            logPushEvent(error: error, scrappingMode: scrappingMode.rawValue)
            }
            self.scrapeNextOrder()
        }
    }
    
    private func logPushEvent(error: ASLException,scrappingMode:String){
        let eventLogs = EventLogs(panelistId: orderDetail.panelistID ?? "", platformId: orderDetail.userID ?? "", section: SectionType.orderUpload.rawValue , type: FailureTypes.jsDetailFail.rawValue, status: EventState.fail.rawValue, message: error.errorMessage, fromDate: self.dateRange?.fromDate ?? "", toDate: self.dateRange?.toDate ?? "", scrapingType: ScrappingType.html.rawValue, scrapingContext: scrappingMode,url: self.params.webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: orderDetail.orderSource ?? "") { response, error in}
    }
    
    func updateUploadRetryCount(orderDetails: OrderDetails) {
        DispatchQueue.global().async {
            var uploadRetryCount: Int16 = 0
            if let count = self.orderDetail.uploadRetryCount {
                uploadRetryCount = count
            }
            print("### orderRetryCount failed",uploadRetryCount, self.orderDetail.orderId)
            uploadRetryCount = uploadRetryCount + 1
            if let userId = self.orderDetail.userID, let panelistId = self.orderDetail.panelistID {
                do {
                    try CoreDataManager.shared.updateRetryCountInOrderDetails(userId: userId, panelistId: panelistId, orderSource: self.params.account.source.value, orderId: self.orderDetail.orderId, retryCount: uploadRetryCount)
                } catch let error {
                    print(AppConstants.tag, "updateOrderDetailsWithExceptionState", error.localizedDescription)
                    let logEventAttributes:[String:String] = [EventConstant.PanelistID: panelistId,
                                                              EventConstant.OrderSourceID: userId,
                                                              EventConstant.OrderSource: self.params.account.source.value,
                                                              EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
            }
        }
    }
}

extension BSOrderDetailsScrapper: DataUploadListener {
    func onDataUploadComplete() {
        guard let queue = self.queue else {
            return
        }
        lock.lock()
        let completed = queue.isEmpty() && self.scrapeQueue.count == 0
        && !self.dataUploader.hasDataForUpload()
        if completed && !isScrapingComplete {
            //Show scrape percentage for manual scraping
            showScrapePercentage(dataUploadComplete: true)

            let detailsTimer = orderDetailsTimer.stop()
            let logEventAttributes = [EventConstant.OrderSource: self.params.account.source.value,
                                      EventConstant.PanelistID: self.params.account.panelistID,
                                      EventConstant.OrderSourceID: self.params.account.userID,
                                      EventConstant.ScrappingTime: detailsTimer]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.onDataUploadSuccess, eventAttributes: logEventAttributes)
            isScrapingComplete = true
            self.params.listener.onScrapeDataUploadCompleted(complete: true, error: nil)
        }
        lock.unlock()
    }
}
