//
//  Account.swift
//  OrderScrapper
//
import Foundation

public protocol Account {
    var userID: String { get }
    var accountState: AccountState { get }
    var userPassword: String { get }
    
    func connect(orderExtractionListener: OrderExtractionListener)
    
    func disconnect(accountDisconnectedListener: AccountDisconnectedListener)
    
    func fetchOrders(orderExtractionListener: OrderExtractionListener)
}
