//
//  AmazonNavigationHelper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine

struct AmazonURL {
    static let signIn           =   "ap/signin"
    static let authApproval     =   "ap/cvf/approval"
    static let twoFactorAuth    =   "ap/mfa"
    static let downloadReport   =   "download-report"
    static let reportID         =   "reportId"
    static let generateReport   =   "gp/b2b/reports/"
}

class AmazonNavigationHelper: NavigationHelper {
    @ObservedObject var viewModel: WebViewModel
    
    var jsResultSubscriber: AnyCancellable? = nil
    let authenticator: Authenticator
    
    required init(_ viewModel: WebViewModel) {
        self.viewModel = viewModel
        self.authenticator = AmazonAuthenticator(viewModel)
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    func navigateWithURL(url: URL?) {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if (urlString.contains(AmazonURL.signIn)) {
            self.authenticator.authenticate()
        } else if (urlString.contains(AmazonURL.authApproval)
                    || urlString.contains(AmazonURL.twoFactorAuth)) {
            self.viewModel.showWebView.send(true)
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            self.injectDownloadReportJS()
        } else if (urlString.contains(AmazonURL.generateReport)) {
            self.injectGenerateReportJS()
        }
    }
    
    private func injectGenerateReportJS() {
        if let reportConfig = self.viewModel.reportConfig {
            let js = "javascript:" +
                "document.getElementById('report-type').value = '" + reportConfig.reportType + "';" +
                "document.getElementById('report-month-start').value = '" + reportConfig.startMonth + "';" +
                "document.getElementById('report-day-start').value = '" + reportConfig.startDate + "';" +
                "document.getElementById('report-year-start').value = '" + reportConfig.startYear + "';" +
                "document.getElementById('report-month-end').value = '" + reportConfig.endMonth + "';" +
                "document.getElementById('report-day-end').value = '" + reportConfig.endDate + "';" +
                "document.getElementById('report-year-end').value = '" + reportConfig.endYear + "';" +
                "document.getElementById('report-confirm').click()"
        
            self.viewModel.jsPublisher.send((.generateReport, js))
        }
    }
    
    private func injectDownloadReportJS() {
        let js = "javascript:" +
            "document.getElementById(window['download-cell-'+new URLSearchParams(window.location.search).get(\"reportId\")].id).click()"
        
        self.viewModel.jsPublisher.send((.downloadReport, js))
    }
}
