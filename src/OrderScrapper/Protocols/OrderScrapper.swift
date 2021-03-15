//
//  File.swift
//  OrderScrapper
//
import Foundation

public protocol OrderScrapper {
    func getAccounts() -> [Account]
    func connectAccount(accountConnectionListener : AccountConnectedListener) -> Void
    func disconnectAccount(account: Account,
                           accountDisconnectedListener : AccountDisconnectedListener) -> Void
    func startOrderExtraction() -> Void
    func verifyAccounts() -> Void
}
