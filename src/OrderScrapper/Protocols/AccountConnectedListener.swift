//
//  AccountConnectedListener.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation
protocol AccountConnectedListener {
    func onAccountConnected(account : Account) -> Void
    func onAccountConnectionFailed(account : Account) -> Void
}
