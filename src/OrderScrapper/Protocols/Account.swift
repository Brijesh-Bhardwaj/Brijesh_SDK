//
//  Account.swift
//  OrderScrapper
//
import Foundation

public protocol Account {
    func getUserEmailId() -> String
    func getLinkStatus() -> AccountState
}
