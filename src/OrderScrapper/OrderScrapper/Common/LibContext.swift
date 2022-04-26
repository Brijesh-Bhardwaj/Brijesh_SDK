//
//  LibContext.swift
//  OrderScrapper
//

import Foundation
import Combine

class LibContext {
    private static var instance: LibContext!
    
    private init() {
        
    }
    
    static var shared: LibContext = {
        if instance == nil {
            instance = LibContext()
        }
        return instance
    }()
    
    var authProvider: AuthProvider!
    var viewPresenter: ViewPresenter!
    var orderExtractorConfig : OrderExtractorConfig!
    var timeoutValue: Double!
    var timerValue: Double! {
        get {
            if self.timeoutValue == nil {
                self.timeoutValue = AppConstants.timeoutCounter
            }
            return self.timeoutValue
        } 
    }
     
    var servicesStatusListener: ServicesStatusListener!
    var manualScrapeTimeOutMessage: String!
    var manualScrapeSuccess: String!
    var scrapeCompletionPublisher = PassthroughSubject<((Bool, OrderFetchSuccessType?), ASLException?), Never>()
    var webAuthErrorPublisher = PassthroughSubject<(Bool, String), Never>()
    var authenticationErrorPublisher = PassthroughSubject<Bool, Never>()
    var isIncetiveFlag: Bool = false
    var onlineScrapingSuccessNote: String!
    var onlineScrapingSuccessMessage: String!
    var onlineScrapingTimeoutMessage: String!
    var lastWeekOrders: LastWeekOrderCount?
    var noOrdersInWeekMessage: String!
    var manualScrapeNote:String!
    var onlineZeroOrdersNote:String!
    var onlineScrapingFailedMessage: String!
    var noNewManualOrders:String!
    var noNewManualOrdersNote: String!
    
    func hasNoOrdersInLastWeek() -> Bool {
        guard let lastWeekOrders = LibContext.shared.lastWeekOrders else {
            return false
        }
        if lastWeekOrders.amazon == 0 &&
            lastWeekOrders.instacart == 0 &&
            lastWeekOrders.walmart == 0 {
            return false
        } else {
          return true
        }
    }
    
}
