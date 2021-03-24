//
//  File.swift
//  OrderScrapper
//
import Foundation

public protocol OrderScrapper {
    func getAccounts() -> [Account]
    func connectAccount(orderExtractionListener : OrderExtractionListener) -> Void
    func disconnectAccount(account: Account,
                           accountDisconnectedListener : AccountDisconnectedListener) -> Void
    func startOrderExtraction(orderExtractionListener: OrderExtractionListener) -> Void
}
