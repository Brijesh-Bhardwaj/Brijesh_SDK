import Foundation
//  OrderExtractionListener.swift
//  OrderScrapper
/*
 A callback protocol to notify the application the status of the
 Account#fetchOrder operation. The application should implement
 this protocol if the status of the operation is required.
 **/
public protocol OrderExtractionListener {
    /// Notifies the app if order extraction operation was successful
    /// - Parameter successType: the success type
    func onOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account)
    
    /// Notifies the app if order extraction operation failed
    /// - Parameter error : the error reason , wrapped in the ASLException object
    func onOrderExtractionFailure(error: ASLException, account: Account)
    
    func showNotification(account: Account)
}
