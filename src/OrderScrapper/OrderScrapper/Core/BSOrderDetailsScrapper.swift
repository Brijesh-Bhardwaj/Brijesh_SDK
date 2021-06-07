//  BSOrderDetailsScrapper.swift
//  OrderScrapper

import Foundation

class BSOrderDetailsScrapper {
    let webClient: BSWebClient
    let webClientDelegate: BSWebNavigationDelegate
    let listener: BSHtmlScrappingStatusListener
    var script: String?
    var dateRange: DateRange?
    var queue: Queue<OrderDetailsMO>?
    var dataUploader: BSDataUploader?
    var orderDetail: OrderDetailsMO?
    
    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate, listener: BSHtmlScrappingStatusListener) {
        self.webClient = webClient
        self.webClientDelegate = delegate
        self.listener = listener
    }
    
    func scrapeOrderDetailPage(script: String, dateRange: DateRange, orderDetails: [OrderDetailsMO]) {
        self.script = script
        self.dateRange = dateRange
        self.queue = Queue(queue: orderDetails)
        scrapeOrder()
    }
    
    func scrapeOrder() {
        orderDetail = queue?.peek()
        if orderDetail != nil {
            if queue!.isEmpty() {
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: orderDetail!.orderSource,
                                      EventConstant.PanelistID: orderDetail!.panelistID,
                                      EventConstant.OrderSourceID: orderDetail!.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResult, eventAttributes: logEventAttributes)
            }
            
            if let script = script, let dateRange = dateRange, let detailUrl = orderDetail?.orderDetailsURL {
                let scriptParam = ScriptParam(script: script, dateRange: dateRange, url: detailUrl, scrappingPage: .details)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
                
                BSHtmlScrapper(webClient: webClient, delegate: webClientDelegate, listener: self)
                    .extractOrders(script: executableScript, url: detailUrl)
            }
        } else {
            print("### Queue empty")
            //TODO handling of success
        }
    }
    
    func uploadScrapeData(data: String) {
        if dataUploader == nil {
            dataUploader = BSDataUploader(dateRange: dateRange!, orderDetail: orderDetail!, listener: self)
        }
        dataUploader?.addData(data: data)
    }
}

extension BSOrderDetailsScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool) {
        
    }
    
    func onHtmlScrappingSucess(response: String) {
        print("### onHtmlScrappingSucess ->> ", response)
        if !response.isEmpty {
            self.uploadScrapeData(data: response)
        }
        self.scrapeOrder()
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        print("### onHtmlScrappingFailure ")
        self.scrapeOrder()
    }
}

extension BSOrderDetailsScrapper: DataUploadListener {
    func onDataUploadComplete() {
        if ((queue?.isEmpty()) != nil) {
            listener.onScrapeDataUploadCompleted(complete: true)
        } else {
            listener.onScrapeDataUploadCompleted(complete: false)
        }
    }
}
