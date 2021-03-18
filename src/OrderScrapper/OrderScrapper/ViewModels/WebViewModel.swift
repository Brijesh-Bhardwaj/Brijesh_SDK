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
    var reportConfig: ReportConfig? = ReportConfig(startDate: "1", startMonth: "1", startYear: "2021", endDate: "31", endMonth: "1", endYear: "2021", reportType: "SHIPMENTS")
    var showWebView = PassthroughSubject<Bool, Never>()
    var webviewError = PassthroughSubject<String, Never>()
    var jsPublisher = PassthroughSubject<(JSInjectValue, String), Never>()
    var jsResultPublisher = PassthroughSubject<(JSInjectValue, (Any?, Error?)), Never>()
    var progressValue = PassthroughSubject<Float, Never>()
}
