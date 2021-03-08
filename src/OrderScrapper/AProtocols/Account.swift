//
//  Account.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation

protocol Account {
    func getUserEmailId() -> String
    func getUserPassword() -> String
    func getLinkStatus() -> StatusEnum
}
