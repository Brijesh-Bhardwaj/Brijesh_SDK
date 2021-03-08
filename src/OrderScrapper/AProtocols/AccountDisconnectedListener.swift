//
//  AccountDisconnectedListener.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation
protocol AccountDisconnectedListener {
    func onAccountDisconnected(account : Account) -> Void
    func onAccountDisconnectionFailed(account : Account) -> Void
}
