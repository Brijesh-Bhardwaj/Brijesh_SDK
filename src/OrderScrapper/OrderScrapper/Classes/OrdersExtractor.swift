//  OrderScrapperLib.swift
//  OrderScrapper

/*
 Represents the bridge between the application and the SDK. This class is the first
 integration point between the app and SDK. The application must call initialize method first before calling any other method
 **/

import Foundation
import UIKit

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
                                  analyticsProvider: AnalyticsProvider?) throws {
        if isInitialized {
            debugPrint(Strings.ErrorLibAlreadyInitialized)
            return
        }
        
        let authToken = authProvider.getAuthToken()
        let panelistId = authProvider.getPanelistID()
        
        if (authToken.isEmpty || panelistId.isEmpty) {
            throw ASLException(errorMessage: Strings.ErrorAuthProviderNotImplemented)
        }
        
        if (!AmazonOrderScrapper.isInitialized()) {
            AmazonOrderScrapper.shared.initialize(authProvider: authProvider,
                                                  viewPresenter: viewPresenter,
                                                  analyticsProvider: analyticsProvider)
        }
        
        //Configure firebase analytics
        if analyticsProvider == nil {
            FirebaseAnalyticsUtil.configure()
        }
        registerFonts()
        
        isInitialized = true
    }
    
    /// Get list of accounts for the given order source type. If this value is not provided then it gives all accounts.
    /// This method asynchronously fetches the accounts and return using the completionhandler callback.
    /// - Parameter orderSource:the order source type
    /// - Parameter completionHandler:closure which gives list of connected accounts for order source
    /// - Throws ASLException: if this method is called before the initialization method
    public static func getAccounts(orderSource: OrderSource?,
                                   completionHandler: @escaping ([Account]) -> Void) throws {
        if isInitialized {
            let panelistId = LibContext.shared.authProvider.getPanelistID()

            _ = AmazonService.getAccounts() { response, error in
                DispatchQueue.global().async {
                    let accountsInDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                    if let response = response  {
                        let accountDetails = response
                        if accountsInDB.isEmpty && accountDetails.isEmpty {
                            DispatchQueue.main.async {
                                completionHandler(accountsInDB)
                            }
                        } else if !accountDetails.isEmpty && accountsInDB.isEmpty {
                            let account = accountDetails[0]
                            CoreDataManager.shared.addAccount(userId: account.amazonId, password: "",
                                                              accountStatus: AccountState.ConnectedButException.rawValue,
                                                              orderSource: OrderSource.Amazon.rawValue, panelistId: panelistId)
                            self.updateStatus(amazonId: account.amazonId, status: AccountState.ConnectedButException.rawValue, message: AppConstants.msgDBEmpty)
                            let accountsFromDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                            DispatchQueue.main.async {
                                completionHandler(accountsFromDB)
                            }
                        } else {
                            DispatchQueue.main.async {
                                completionHandler(accountsInDB)
                            }
                        }
                    } else {
                        DispatchQueue.global().async {
                            let accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                            DispatchQueue.main.async {
                                completionHandler(accounts)
                            }
                        }
                    }
                }
                
            }
        } else {
            throw ASLException(errorMessage: Strings.ErrorLibNotInitialized)
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
            throw ASLException(errorMessage: Strings.ErrorLibNotInitialized)
        }
    }
    
    private static func registerFonts() {
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Bold.otf")
        UIFont.registerFont(withFilenameString: "SF-Pro-Rounded-Regular.otf")
    }
    
    private static func updateStatus(amazonId: String, status: String, message: String) {
        _ = AmazonService.updateStatus(amazonId: amazonId, status: status, message: message) { response, error in
            //Todo
        }
    }
}
