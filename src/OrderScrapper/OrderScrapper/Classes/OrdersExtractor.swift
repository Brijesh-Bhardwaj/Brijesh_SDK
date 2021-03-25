//
//  OrderScrapperLib.swift
//  OrderScrapper

import Foundation

public class OrdersExtractor {
    private static var isInitialized = false
    
    public static func initialize(authProvider: AuthProvider,
                                  viewPresenter: ViewPresenter) throws {
        if isInitialized {
            throw ASLException(errorMessage: Strings.ErrorLibAlreadyInitialized)
        }
        
        let authToken = authProvider.getAuthToken()
        let panelistId = authProvider.getPanelistID()
        
        if (authToken.isEmpty || panelistId.isEmpty) {
            throw ASLException(errorMessage: Strings.ErrorAuthProviderNotImplemented)
        }
        
        if (!AmazonOrderScrapper.isInitialized()) {
            AmazonOrderScrapper.shared.initialize(authProvider: authProvider, viewPresenter: viewPresenter)
        }
        isInitialized = true
    }
    
    public static func getAccounts(orderSource: OrderSource?,
                                   completionHandler: @escaping ([Account]) -> Void) throws {
        if isInitialized {
            DispatchQueue.global().async {
                let accounts = CoreDataManager.shared.fetch(orderSource: orderSource)
                DispatchQueue.main.async {
                    completionHandler(accounts)
                }
            }
        } else {
            throw ASLException(errorMessage: Strings.ErrorLibNotInitialized)
        }
    }
    
    public static func registerAccount(orderSource: OrderSource,
                                       orderExtractionListner: OrderExtractionListener) throws {
        if isInitialized {
            let account = CoreDataManager.shared.createNewAccount()
            account.userId = ""
            account.password = ""
            account.accountState = .NeverConnected
            account.orderSource = orderSource.rawValue
            
            account.connect(orderExtractionListener: orderExtractionListner)
        } else {
            throw ASLException(errorMessage: Strings.ErrorLibNotInitialized)
        }
    }
}
