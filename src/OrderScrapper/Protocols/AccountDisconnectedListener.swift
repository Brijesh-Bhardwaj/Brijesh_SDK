//
//  AccountDisconnectedListener.swift
//  OrderScrapper
//
import Foundation
protocol AccountDisconnectedListener {
    func onAccountDisconnected(account : Account) -> Void
    func onAccountDisconnectionFailed(account : Account) -> Void
}
