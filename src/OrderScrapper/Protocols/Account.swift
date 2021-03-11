//
//  Account.swift
//  OrderScrapper
//
import Foundation
protocol Account {
    func getUserEmailId() -> String
    func getLinkStatus() -> AccountState
}
