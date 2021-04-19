import Foundation
import UIKit
//  ViewPresenter.swift
//  OrderScrapper
/*
 The 'ViewPresenter' protocol the SDK utilizes to show UI components.
 The application must implement this method and provide necessary
 implementation to show/remove UI
 **/
public protocol ViewPresenter {
    /// Notifies the application to show the provided UIViewController component.
    /// - Parameter view: UIViewController object to present the UI component
    func presentView(view: UIViewController) -> Void
    
    /// Notifies the application to dismiss the presented UI component
    func dismissView() -> Void
}
