//
//  File.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation
protocol OrderScrapper {
    func getAccounts() -> [Account]
    func connectAccount(accountConnectionListener : AccountConnectedListener) -> Void
    func disconnectAccount(account: Account,
                           accountDisconnectedListener : AccountDisconnectedListener) -> Void
    func startOrderExtraction() -> Void
    func verifyAccounts() -> Void

}
