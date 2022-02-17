//  OrderScrapperLib.swift
//  OrderScrapper

/*
 Represents the bridge between the application and the SDK. This class is the first
 integration point between the app and SDK. The application must call initialize method first before calling any other method
 **/

import Foundation
import UIKit
import Sentry

public class OrdersExtractor {
    private init() {}
    
    private static var isInitialized = false
    
    /// Initializes the library and prepares it for the operation
    /// - Parameter authProvider: It has authToken and panelistId
    /// - Parameter viewPresenter: It has viewPresenter to show and hide the view
    /// - Parameter analyticsProvider: It has analytics provider to log the events
    /// - Throws ASLException: If the rauth provider does not provide the required auth token and panelist ID values
    public static func initialize(authProvider: AuthProvider,
                                  viewPresenter: ViewPresenter,
                                  analyticsProvider: AnalyticsProvider?,
                                  orderExtractionConfig: OrderExtractorConfig,
                                  servicesStatusListener: ServicesStatusListener) throws {
        
        let authToken = authProvider.getAuthToken()
        let panelistId = authProvider.getPanelistID()
        let baseUrl = orderExtractionConfig.baseURL
        let appName = orderExtractionConfig.appName
        
        if (!baseUrl.isEmpty && !appName.isEmpty)
        {
            LibContext.shared.orderExtractorConfig = orderExtractionConfig
        } else {
            let error = ASLException(errorMessage: Strings.ErrorConfigsMissing, errorType: nil)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            throw error
        }
        if (authToken.isEmpty || panelistId.isEmpty) {
            let error = ASLException(errorMessage: Strings.ErrorConfigsMissing, errorType: nil)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            throw error
        }
        
        AmazonOrderScrapper.shared.initialize(authProvider: authProvider,
                                              viewPresenter: viewPresenter,
                                              analyticsProvider: analyticsProvider,
                                              servicesStatusListener: servicesStatusListener)
        
        //Configure firebase analytics
        if analyticsProvider == nil {
            FirebaseAnalyticsUtil.configure()
        }
        registerFonts()
        
        //get Scrapper config details
        ConfigManager.shared.loadConfigs(orderSources: [.Amazon,.Instacart,.Kroger,.Walmart]) { scrapeConfigs, error in
            if let scrapeConfigs = scrapeConfigs {
                FirebaseAnalyticsUtil.initSentrySDK(scrapeConfigs: scrapeConfigs)
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_init_library")
            }
        }
//        //get scripts for the order sources
//        BSScriptFileManager.shared.loadScriptFile()

        _ = AmazonService.getConfigs() {configs, error in
            if let configs = configs {
                if let timeoutValue = configs.timeoutValue {
                    LibContext.shared.timeoutValue = timeoutValue
                } else {
                    LibContext.shared.timeoutValue = AppConstants.timeoutCounter
                }
            } else {
                LibContext.shared.timeoutValue = AppConstants.timeoutCounter

                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {

                    let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                    LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
                }
            }
        }
        
        isInitialized = true
    }
    
    /// Get list of accounts for the given order source type. If this value is not provided then it gives all accounts.
    /// This method asynchronously fetches the accounts and return using the completionhandler callback.
    /// - Parameter orderSource:the order source type
    /// - Parameter completionHandler:closure which gives list of connected accounts for order source
    /// - Throws ASLException: if this method is called before the initialization method
    public static func getAccounts(orderSource: OrderSource?...,
                                   completionHandler: @escaping ([String: AccountInfo]) -> Void) throws {
        if isInitialized {
            var orderSources:[OrderSource] = []
            
            for source in orderSource {
                if let source = source {
                    orderSources.append(source)
                }
            }
            AccountsManager.shared.fetchAccounts(orderSources: orderSources) { (response) in
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
            
        } else {
            let error = ASLException(errorMessage: Strings.ErrorLibNotInitialized, errorType: nil)
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.PanelistID: panelistId,
                                  EventConstant.EventName: EventType.LibNotInit,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.LibNotInit, eventAttributes: logEventAttributes)
            throw error
        }
    }
    /// Registers a new account in the SDK. The SDK shows  the required screen for this operation.
    /// - Parameter orderSource: the order source type
    /// - Parameter orderExtractionListner: callback interface to noftify the status
    /// - Throws ASLException: if this method is called before the initialization method
    public static func registerAccount(orderSource: OrderSource,
                                       orderExtractionListner: OrderExtractionListener) throws {
        if isInitialized {
            let account = CoreDataManager.shared.createNewAccount()
            account.userId = ""
            account.password = ""
            account.accountState = .NeverConnected
            account.orderSource = orderSource.rawValue
            account.panelistId = LibContext.shared.authProvider.getPanelistID()
            
            account.connect(orderExtractionListener: orderExtractionListner)
        } else {
            let error =  ASLException(errorMessage: Strings.ErrorConfigsMissing, errorType: nil)
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: orderSource.value,
                                  EventConstant.PanelistID: panelistId,
                                  EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.ConfigsMissing, eventAttributes: logEventAttributes)
            throw error
        }
    }
    
    public func scanOnlineOrders(orderExtractionListener: OrderExtractionListener, accounts: Account?...) {
        AmazonOrderScrapper.shared.scanAllOrders(accounts: accounts, orderExtractionListener: orderExtractionListener)
    }
    
    private static func registerFonts() {
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Bold.otf")
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Regular.otf")
    }
}
