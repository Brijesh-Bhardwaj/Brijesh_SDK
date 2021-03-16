//
//  ViewModel.swift
//  OrderScrapper
//

import Foundation
import Combine

class WebViewModel: ObservableObject {
    var userEmail: String?
    var userPassword: String?
    var showWebView = PassthroughSubject<Bool, Never>()
    var webviewError = PassthroughSubject<String, Never>()
    var jsPublisher = PassthroughSubject<(JSInjectValue, String), Never>()
    var jsResultPublisher = PassthroughSubject<(JSInjectValue, (Any?, Error?)), Never>()
}
