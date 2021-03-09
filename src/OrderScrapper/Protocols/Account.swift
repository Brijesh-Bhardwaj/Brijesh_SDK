//
//  Account.swift
//  OrderScrapper
//
import Foundation
protocol Account {
    func getUserEmailId() -> String
    func getUserPassword() -> String
    func getLinkStatus() -> StatusEnum
}
