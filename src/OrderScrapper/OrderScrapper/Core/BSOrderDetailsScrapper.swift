//  BSOrderDetailsScrapper.swift
//  OrderScrapper

import Foundation

class BSOrderDetailsScrapper {
    let params: BSHtmlScrapperParams
    var script: String!
    var dateRange: DateRange?
    var queue: Queue<OrderDetails>!
    var orderDetail: OrderDetails!
    
    lazy var dataUploader: BSDataUploader = {
        return BSDataUploader(dateRange: self.dateRange!, listener: self)
    }()
    
    lazy var htmlScrapper: BSHtmlScrapper = {
        return BSHtmlScrapper(params: self.scrapperParams)
    }()
    
    lazy var scrapperParams: BSHtmlScrapperParams = {
        return BSHtmlScrapperParams(webClient: self.params.webClient, webNavigationDelegate: self.params.webNavigationDelegate, listener: self, authenticator: self.params.authenticator, configuration: self.params.configuration, account: self.params.account)
    }()
    
    init(scrapperParams: BSHtmlScrapperParams) {
        self.params = scrapperParams
    }
    
    func scrapeOrderDetailPage(script: String, dateRange: DateRange, orderDetails: [OrderDetails]) {
        self.script = script
        self.dateRange = dateRange
        self.queue = Queue(queue: orderDetails)
        
        scrapeOrder()
    }
    
    func scrapeOrder() {
        orderDetail = queue.peek()
        if orderDetail != nil {
            if queue!.isEmpty() {
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: orderDetail.orderSource ?? "",
                                      EventConstant.PanelistID: orderDetail.panelistID ?? "",
                                      EventConstant.OrderSourceID: orderDetail.userID ?? "",
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgScrappingOrderDetailResult, eventAttributes: logEventAttributes)
            }
            
            if let script = script, let detailUrl = orderDetail?.detailsUrl {
                //Param for order detail page scrapping
                let scriptParam = ScriptParam(script: script, dateRange: nil, url: detailUrl, scrappingPage: .details, urls: nil, orderId: orderDetail.orderId)
                let executableScript = ExecutableScriptBuilder().getExecutableScript(param: scriptParam)
                
                self.htmlScrapper.extractOrders(script: executableScript, url: detailUrl)
            }
        } else {
            print("### Queue empty")
            onDataUploadComplete()
        }
    }
    
    func uploadScrapeData(data: Dictionary<String, Any>) {
        self.dataUploader.addData(data: data, orderDetail: orderDetail!)
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
            if let status = jsCallBackResult["status"] as? String {
                if status == "success" {
                    print("### onHtmlScrappingSucess for OrderDetail", response)
                    if let orderDetails = jsCallBackResult["data"] as? Dictionary<String,Any> {
                        self.uploadScrapeData(data: orderDetails)
                    }
                    self.scrapeOrder()
                } else if status == "failed" {
                    self.scrapeOrder()
                }
            }
        }
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        print("### onHtmlScrappingFailure ")
        if error.errorType == ErrorType.authError {
            self.params.listener.onScrapeDataUploadCompleted(complete: false, error: error)
        } else {
            self.scrapeOrder()
        }
    }
}

extension BSOrderDetailsScrapper: DataUploadListener {
    func onDataUploadComplete() {
        guard let queue = self.queue else {
            return
        }
        
        let completed = queue.isEmpty() && !self.dataUploader.hasDataForUpload()
        if completed {
            self.params.listener.onScrapeDataUploadCompleted(complete: true, error: nil)
        } 
    }
}
