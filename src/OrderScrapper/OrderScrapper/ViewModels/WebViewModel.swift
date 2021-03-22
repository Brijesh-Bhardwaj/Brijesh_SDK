//
//  ViewModel.swift
//  OrderScrapper
//

import Foundation
import Combine

class WebViewModel: ObservableObject {
    var userEmail: String?
    var userPassword: String?
    //TODO: This information will be fetched from the API
    var reportConfig: ReportConfig?
    var showWebView = PassthroughSubject<Bool, Never>()
    var webviewError = PassthroughSubject<Bool, Never>()
    var authError = PassthroughSubject<Bool, Never>()
    var jsPublisher = PassthroughSubject<(JSInjectValue, String), Never>()
    var jsResultPublisher = PassthroughSubject<(JSInjectValue, (Any?, Error?)), Never>()
    var progressValue = PassthroughSubject<Float, Never>()
    var progressMessage = PassthroughSubject<String, Never>()
    var headingMessage = PassthroughSubject<String, Never>()
    var stepMessage = PassthroughSubject<String, Never>()
    var navigationPublisher = PassthroughSubject<WebViewNavigation, Never>()
    var completionPublisher = PassthroughSubject<Bool, Never>()
}

enum WebViewNavigation {
    case reload
}
