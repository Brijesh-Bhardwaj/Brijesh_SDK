//
//  AccountConnectedListener.swift
//  OrderScrapper
//
import Foundation
protocol AccountConnectedListener {
    func onAccountConnected(account : Account) -> Void
    func onAccountConnectionFailed(account : Account) -> Void
}
