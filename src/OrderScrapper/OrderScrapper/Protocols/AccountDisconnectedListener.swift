//
//  AccountDisconnectedListener.swift
//  OrderScrapper
//
import Foundation

public protocol AccountDisconnectedListener {
    func onAccountDisconnected(account : Account) -> Void
    func onAccountDisconnectionFailed(account : Account) -> Void
}
