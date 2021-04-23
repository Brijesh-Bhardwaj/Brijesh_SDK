import Foundation
//  AccountDisconnectedListener.swift
//  OrderScrapper
/*
 The 'AccountDisconnectedListener' protocol to notify
 the Account#disconnect operation to the application
 **/
public protocol AccountDisconnectedListener {
    /// Notifies the app that the account is successfully disconnected
    /// - Parameter account: the account which is disconnected
    func onAccountDisconnected(account : Account) -> Void
    
    ///Notifies the app that the account disconnction operation has failed
    /// - Parameter account: the account for which the account disconnect operation was performed
    /// - Parameter error: the error reason , wrapped in the ASLException object
    func onAccountDisconnectionFailed(account : Account, error: ASLException) -> Void
}
