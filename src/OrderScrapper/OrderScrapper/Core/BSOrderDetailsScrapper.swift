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
    
    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate, listener: BSHtmlScrappingStatusListener) {
        self.webClient = webClient
        self.webClientDelegate = delegate
        self.listener = listener
    }
    
    func scrapeOrderDetailPage(script: String, dateRange: DateRange, orderDetails: [OrderDetailsMO]) {
        self.script = script
        self.dateRange = dateRange
        self.queue = Queue(orderDetails: orderDetails)
        scrapeOrder()
        
        
    }
    
    func scrapeOrder() {
        let orderDetail = queue?.peek()
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
}

extension BSOrderDetailsScrapper: BSHtmlScrappingStatusListener {
    func onHtmlScrappingSucess(response: String) {
        print("### onHtmlScrappingSucess ", response)
        self.scrapeOrder()
    }
    
    func onHtmlScrappingFailure(error: ASLException) {
        print("### onHtmlScrappingFailure ")
        self.scrapeOrder()
    }
}
