//
//  ViewModel.swift
//  OrderScrapper
//

import Foundation
import Combine

class ViewModel: ObservableObject {
    var webViewNavigationPublisher = PassthroughSubject<WebViewNavigation, Never>()
    var showWebTitle = PassthroughSubject<String, Never>()
    var showLoader = PassthroughSubject<Bool, Never>()
    var valuePublisher = PassthroughSubject<String, Never>()
    
    var userEmail: String?
    var userPassword: String?
    var showWebView = PassthroughSubject<Bool, Never>()
    var jsPublisher = PassthroughSubject<(JSInjectValue, String), Never>()
    var jsResultPublisher = PassthroughSubject<(JSInjectValue, (Any?, Error?)), Never>()
}

// For identifiying WebView's forward and backward navigation
enum WebViewNavigation {
    case backward, forward, reload
}

// For identifying what type of url should load into WebView
enum WebUrlType {
    case localUrl, publicUrl
}
