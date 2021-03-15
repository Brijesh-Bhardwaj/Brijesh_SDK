//
//  AccountConnectedListener.swift
//  OrderScrapper
//
import Foundation

public protocol AccountConnectedListener {
    func onAccountConnected(account : Account) -> Void
    func onAccountConnectionFailed(account : Account) -> Void
}
