//
//  Account.swift
//  OrderScrapper
//
import Foundation

public protocol Account {
    var userID: String { get }
    var accountState: AccountState { get }
}
