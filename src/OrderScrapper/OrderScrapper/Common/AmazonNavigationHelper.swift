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
    let authenticator: AmazonAuthenticator
    
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
        let startDay = "1";
        let startMonth = "5";
        let startyear = "2008";
        let endDay = "17";
        let endMonth = "2";
        let endYear = "2021";
        let reportType = "SHIPMENTS";
        
        let js = "javascript:" +
            "document.getElementById('report-type').value = '" + reportType + "';" +
            "document.getElementById('report-month-start').value = '" + startMonth + "';" +
            "document.getElementById('report-day-start').value = '" + startDay + "';" +
            "document.getElementById('report-year-start').value = '" + startyear + "';" +
            "document.getElementById('report-month-end').value = '" + endMonth + "';" +
            "document.getElementById('report-day-end').value = '" + endDay + "';" +
            "document.getElementById('report-year-end').value = '" + endYear + "';" +
            "document.getElementById('report-confirm').click()"
        
        self.viewModel.jsPublisher.send((.generateReport, js))
    }
    
    private func injectDownloadReportJS() {
        let js = "javascript:" +
            "document.getElementById(window['download-cell-'+new URLSearchParams(window.location.search).get(\"reportId\")].id).click()"
        
        self.viewModel.jsPublisher.send((.downloadReport, js))
    }
}
