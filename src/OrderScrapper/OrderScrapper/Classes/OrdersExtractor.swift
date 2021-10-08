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
                                  orderExtractionConfig: OrderExtractorConfig) throws {
        
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
                                              analyticsProvider: analyticsProvider)
        
        //Configure firebase analytics
        if analyticsProvider == nil {
            FirebaseAnalyticsUtil.configure()
        }
        registerFonts()
        
        //get Scrapper config details
        ConfigManager.shared.loadConfigs(orderSource: .Amazon) { scrapeConfigs, error in
            if let scrapeConfigs = scrapeConfigs {
                FirebaseAnalyticsUtil.initSentrySDK(scrapeConfigs: scrapeConfigs)
            }
        }
        //get scripts for the order sources
        BSScriptFileManager.shared.loadScriptFile()

        _ = AmazonService.getConfigs() {configs, error in
            if let configs = configs {
                if let timeoutValue = configs.timeoutValue {
                    LibContext.shared.timeoutValue = timeoutValue
                } else {
                    LibContext.shared.timeoutValue = AppConstants.timeoutCounter
                }
            } else {
                LibContext.shared.timeoutValue = AppConstants.timeoutCounter
            }
        }
        
        isInitialized = true
    }
    
    /// Get list of accounts for the given order source type. If this value is not provided then it gives all accounts.
    /// This method asynchronously fetches the accounts and return using the completionhandler callback.
    /// - Parameter orderSource:the order source type
    /// - Parameter completionHandler:closure which gives list of connected accounts for order source
    /// - Throws ASLException: if this method is called before the initialization method
    public static func getAccounts(orderSource: OrderSource?,
                                   completionHandler: @escaping ([Account], Bool) -> Void) throws {
        if isInitialized {
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            var hasNeverConnected: Bool = false
            _ = AmazonService.getAccounts() { response, error in
                DispatchQueue.global().async {
                    let accountsInDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                    
                    if let response = response  {
                        hasNeverConnected = response.hasNeverConnected
                        guard let accountDetails = response.accounts else {
                            if !accountsInDB.isEmpty {
                                CoreDataManager.shared.deleteAccountsByPanelistId(panelistId: panelistId)
                            }
                            let accounts = [UserAccountMO]()
                            DispatchQueue.main.async {
                                completionHandler(accounts, hasNeverConnected)
                            }
                            return
                        }
                        
                        if accountsInDB.isEmpty && accountDetails.isEmpty {
                            DispatchQueue.main.async {
                                completionHandler(accountsInDB, hasNeverConnected)
                            }
                        } else if !accountDetails.isEmpty && accountsInDB.isEmpty {
                            let account = accountDetails[0]
                            let statusToUpdate = (account.status == AccountState.Connected.rawValue) ? AccountState.ConnectedButException.rawValue : account.status
                            
                            CoreDataManager.shared.addAccount(userId: account.amazonId, password: "",
                                                              accountStatus:statusToUpdate,
                                                              orderSource: OrderSource.Amazon.rawValue, panelistId: panelistId)
                            let accountsFromDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                            accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                            DispatchQueue.main.async {
                                completionHandler(accountsFromDB, hasNeverConnected)
                            }
                        } else {
                            if let account = accountDetails.first, let accountInDb = accountsInDB.first {
                                if account.amazonId.elementsEqual(accountInDb.userID) {
                                    accountsInDB.first?.isFirstConnectedAccount = account.firstaccount
                                    DispatchQueue.main.async {
                                        completionHandler(accountsInDB, hasNeverConnected)
                                    }
                                } else {
                                    CoreDataManager.shared.deleteAccountsByPanelistId(panelistId: panelistId)
                                    CoreDataManager.shared.addAccount(userId: account.amazonId,
                                                                      password: "",
                                                                      accountStatus:AccountState.ConnectedButException.rawValue,
                                                                      orderSource: OrderSource.Amazon.rawValue,
                                                                      panelistId: panelistId)
                                    let accountsFromDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                                    accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                                    DispatchQueue.main.async {
                                        completionHandler(accountsFromDB, hasNeverConnected)
                                    }
                                }
                            } else {
                                if let account = accountDetails.first {
                                    accountsInDB.first?.isFirstConnectedAccount = account.firstaccount
                                }
                                DispatchQueue.main.async {
                                    completionHandler(accountsInDB, hasNeverConnected)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.global().async {
                            let accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                            DispatchQueue.main.async {
                                completionHandler(accounts, hasNeverConnected)
                            }
                        }
                    }
                }
                
            }
        } else {
            let error = ASLException(errorMessage: Strings.ErrorLibNotInitialized, errorType: nil)
            FirebaseAnalyticsUtil.logSentryError(error: error)
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
            FirebaseAnalyticsUtil.logSentryError(error: error)
            throw error
        }
    }
    
    private static func registerFonts() {
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Bold.otf")
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Regular.otf")
    }
    
    private static func updateStatus(amazonId: String, status: String, message: String, orderStatus: String) {
        _ = AmazonService.updateStatus(amazonId: amazonId, status: status, message: message, orderStatus: orderStatus) { response, error in
            //Todo
        }
    }
    
    
}
