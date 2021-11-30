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
    
    func scrapeOrderDetailPage(script: String, orderDetails: [OrderDetails], mode: ScrapingMode?) {
        self.script = script
        self.queue = Queue(queue: orderDetails)
        self.scrappingMode = mode
        
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
                let scriptParam = ScriptParam(script: script, dateRange: nil, url: detailUrl, scrappingPage: .details, urls: nil, orderId: orderDetail.orderId)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
                self.scrapeQueue.append(orderDetail.orderId)
                self.htmlScrapper.extractOrders(script: executableScript, url: detailUrl)
            }
        } else {
            print("### Queue empty")
            onDataUploadComplete()
        }
    }
    
    private func uploadScrapeData(data: Dictionary<String, Any>) {
        self.dataUploader.addData(data: data, orderDetail: orderDetail!)
    }
    
    private func scrapeNextOrder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            guard let self = self else { return }
            self.scrapeQueue.remove(at: 0)
            self.scrapeOrder()
        }
    }
}

extension BSOrderDetailsScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool, error: ASLException?) {
        //NA
    }
    
    func onHtmlScrappingSucess(response: String) {
        let jsonData = response.data(using: .utf8)!
        let object = try? JSONSerialization.jsonObject(with: jsonData, options: [])
        
        if let jsCallBackResult = object as? Dictionary<String,Any?> {
            if let type  = jsCallBackResult["type"] as? String {
                if type == "orderdetails" {
                    if let status = jsCallBackResult["status"] as? String {
                        if status == "success" {
                            let timerValue = self.timer.stop()
                            let orderDataCount = jsCallBackResult["data"] as? Dictionary<String,Any>
                            let message = "\(Strings.ScrappingPageDetails) + \(timerValue) + \(String(describing: orderDataCount?.count)))"
                            FirebaseAnalyticsUtil.logSentryMessage(message: message)
                            var logEventAttributes = [EventConstant.Message: message, EventConstant.OrderSource: orderDetail.orderSource ?? "", EventConstant.Status: EventStatus.Success, EventConstant.ScrappingType: ScrappingType.html.rawValue]
                            if let scrappingMode = scrappingMode {
                                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
                            }
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultSuccess, eventAttributes: logEventAttributes)
                            print("### onHtmlScrappingSucess for OrderDetail", response)
                            if let orderDetails = jsCallBackResult["data"] as? Dictionary<String,Any> {
                                self.uploadScrapeData(data: orderDetails)
                            }
                            self.scrapeNextOrder()
                            //TODO Check
                        } else if status == "failed" {
                            let timerValue = self.timer.stop()
                            let orderDataCount = jsCallBackResult["data"] as? Dictionary<String,Any>
                            let message = "\(Strings.ScrappingPageListing) + \(timerValue) + \(String(describing: orderDataCount?.count)))"
                            self.scrapeNextOrder()
                            FirebaseAnalyticsUtil.logSentryMessage(message: message)
                            
                            var error: String
                            if let errorReason = jsCallBackResult["errorMessage"] as? String {
                                error = errorReason
                            } else {
                                error = Strings.ErrorOrderExtractionFailed
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
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResultFilure, eventAttributes: logEventAttributes)
                        }
                    }
                }
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        print("### onHtmlScrappingFailure ")
        if error.errorType == ErrorType.authError {
            self.params.listener.onScrapeDataUploadCompleted(complete: false, error: error)
            
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                                      EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                                      EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                      EventConstant.EventName: EventType.HtmlScrapingFailed,
                                                      EventConstant.Status: EventStatus.Failure]
            if let scrappingMode = self.scrappingMode {
                logEventAttributes[EventConstant.ScrappingMode] = scrappingMode.rawValue
            }
            FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        } else {
            self.scrapeNextOrder()
        }
    }
}

extension BSOrderDetailsScrapper: DataUploadListener {
    func onDataUploadComplete() {
        guard let queue = self.queue else {
            return
        }
        
        if let mode = self.scrappingMode, mode == .Foreground {
            self.params.listener.onScrapeDataUploadCompleted(complete: true, error: nil)
        } else {
            let completed = queue.isEmpty() && self.scrapeQueue.count == 0
                && !self.dataUploader.hasDataForUpload()
            if completed {
                self.params.listener.onScrapeDataUploadCompleted(complete: true, error: nil)
            }
        }
    }
}
