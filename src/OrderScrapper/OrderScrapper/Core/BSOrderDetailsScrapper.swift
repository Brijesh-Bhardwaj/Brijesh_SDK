//  BSOrderDetailsScrapper.swift
//  OrderScrapper

import Foundation

class BSOrderDetailsScrapper {
    let webClient: BSWebClient
    let webClientDelegate: BSWebNavigationDelegate
    let listener: BSHtmlScrappingStatusListener
    var htmlScrapper: BSHtmlScrapper!
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
        self.htmlScrapper = BSHtmlScrapper(webClient: webClient, delegate: webClientDelegate, listener: self)
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
            
            if let script = script, let detailUrl = orderDetail?.orderDetailsURL {
                //Param for order detail page scrapping
                let scriptParam = ScriptParam(script: script, dateRange: nil, url: detailUrl, scrappingPage: .details, urls: nil, orderId: orderDetail?.orderID)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
                
                self.htmlScrapper.extractOrders(script: executableScript, url: detailUrl)
            }
        } else {
            print("### Queue empty")
            //TODO handling of success
        }
    }
    
    func uploadScrapeData(data: Dictionary<String,Any>) {
        if dataUploader == nil {
            dataUploader = BSDataUploader(dateRange: dateRange!, orderDetail: orderDetail!, listener: self)
        }
        dataUploader?.addData(data: data)
    }
}

extension BSOrderDetailsScrapper: BSHtmlScrappingStatusListener {
    func onScrapeDataUploadCompleted(complete: Bool) {
        //NA
    }
    
    func onHtmlScrappingSucess(response: String) {
        let jsonData = response.data(using: .utf8)!
        let object = try? JSONSerialization.jsonObject(with: jsonData, options: [])
        
        if let jsCallBackResult = object as? Dictionary<String,Any?> {
            if let status = jsCallBackResult["status"] as? String {
                if status == "success" {
                    print("### onHtmlScrappingSucess for OrderDetail", response)
                    if let orderDetails = jsCallBackResult["data"] as? Dictionary<String,Any> {
                        self.uploadScrapeData(data: orderDetails)
                    }
                    self.scrapeOrder()
                }
            }
        }
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
