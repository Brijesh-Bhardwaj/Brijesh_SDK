import Foundation
//  File.swift
//  OrderScrapper
/*
 The 'OrderScrapper' protocol declares methods to get array of accounts,
 to change account state as connected and disconnected
  **/
public protocol OrderScrapper {
    /// Method gives array of accounts from core data
    /// - Returns [Account]: returns array of accounts
    func getAccounts() -> [Account]
    
    /// method to change  account state as connected
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess
    /// and onOrderExtractionFailure callback
    /// - Returns Void : returns Void
    func connectAccount(orderExtractionListener : OrderExtractionListener) -> Void
    
    // method to change  account state as disconnected
    /// - Parameter accountDisconnectedListener: It is a listener which gives onAccountDisconnected
    /// and onAccountDisconnectionFailed callback
    /// - Returns Void : returns Void
    func disconnectAccount(account: Account,
                           accountDisconnectedListener : AccountDisconnectedListener) -> Void
    
    /// method for order extraction for user account
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess
    /// and onOrderExtractionFailure callback
    /// - Returns Void : returns Void
    func startOrderExtraction(orderExtractionListener: OrderExtractionListener) -> Void
}
