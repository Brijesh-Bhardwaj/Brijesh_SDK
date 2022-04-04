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
}
