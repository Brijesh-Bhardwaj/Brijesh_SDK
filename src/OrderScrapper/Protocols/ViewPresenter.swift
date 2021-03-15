//
//  ViewPresenter.swift
//  OrderScrapper
//
import Foundation
import UIKit

public protocol ViewPresenter {
    func presentView(view: UIViewController) -> Void
    func dismissView() -> Void
}
