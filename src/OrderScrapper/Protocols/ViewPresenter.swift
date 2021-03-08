//
//  ViewPresenter.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation
public protocol ViewPresenter {
    //TODO presentView() params
    func presentView() -> Void
    func dismissView() -> Void
}
