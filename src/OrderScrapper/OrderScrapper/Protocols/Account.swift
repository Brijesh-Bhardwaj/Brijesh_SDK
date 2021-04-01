import Foundation
//  Account.swift
//  OrderScrapper
/*
 Represent a user account object. Provide account details of user as well
 as should be used to connect , disconnect and fetch orders
 **/
public protocol Account {
    ///The user ID associated with the account
    var userID: String { get }
    
    ///The current state of the connected account
    var accountState: AccountState { get }
    
    /// The encrypted password associated with the account
    var userPassword: String { get }
    
    /// Connects to the respective e-commerce site and fetches the receipts internally. If the account is
    /// not yet connected this method ensures to show the 'Connect Account' screen to connect the account
    /// - Parameter orderExtractionListener: protocol which notifies the caller about the status
    /// of the order extraction process
    func connect(orderExtractionListener: OrderExtractionListener)
    
    /// Marks the account as disconnected and changes the account state value to ConnectedAndDisconnected
    /// - Parameter accountDisconnectedListener: protocol which notifies the application about
    /// the disconnection status of account
    func disconnect(accountDisconnectedListener: AccountDisconnectedListener)
    
    ///Fetches receipts for this account
    /// - Parameter orderExtractionListener: callback interface to notify the caller
    /// about the status of order extraction process
    func fetchOrders(orderExtractionListener: OrderExtractionListener)
}
