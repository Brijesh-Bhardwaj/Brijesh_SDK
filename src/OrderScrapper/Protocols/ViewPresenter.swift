//
//  ViewPresenter.swift
//  OrderScrapper
//
import Foundation
public protocol ViewPresenter {
    //TODO presentView() params
    func presentView() -> Void
    func dismissView() -> Void
}
