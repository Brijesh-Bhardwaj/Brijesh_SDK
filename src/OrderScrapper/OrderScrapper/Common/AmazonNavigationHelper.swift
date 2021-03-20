//
//  AmazonNavigationHelper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine
import RNCryptor

struct AmazonURL {
    static let signIn           =   "ap/signin"
    static let authApproval     =   "ap/cvf/approval"
    static let twoFactorAuth    =   "ap/mfa"
    static let downloadReport   =   "download-report"
    static let reportID         =   "reportId"
    static let generateReport   =   "gp/b2b/reports/"
}

private enum Step {
    case authentication, generateReport, downloadReport, parseCSV, uploadReport
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
            self.viewModel.progressValue.send(getProgressPercentage(step: .authentication))
            //On authentication add user account details to DB
            addUserAccountInDB()
        } else if (urlString.contains(AmazonURL.authApproval)
                    || urlString.contains(AmazonURL.twoFactorAuth)) {
            self.viewModel.showWebView.send(true)
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            self.injectDownloadReportJS()
            self.viewModel.progressValue.send(getProgressPercentage(step: .downloadReport))
        } else if (urlString.contains(AmazonURL.generateReport)) {
            self.injectGenerateReportJS()
            self.viewModel.progressValue.send(getProgressPercentage(step: .generateReport))
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
    
    /*
     * get progress value in the range 0 to 1 from step number
     **/
    private func getProgressPercentage(step : Step) -> Float {
        var progressValue: Float = 0
        switch step {
        case .authentication:
            progressValue = 1;
        case .generateReport:
            progressValue = 2;
        case .downloadReport:
            progressValue = 3;
        case .parseCSV:
            progressValue = 4;
        case .uploadReport:
            progressValue = 5;
        }
        print("ProgressStep ",progressValue)
        return progressValue/AppConstants.numberOfSteps
    }
    
    /*
     * add user account details in DB
     */
    private func addUserAccountInDB() {
        let userId = self.viewModel.userEmail!
        let userPassword = self.viewModel.userPassword!
        //Encrypt password before storing into DB
        let encrytedPassword = RNCryptoUtil.encryptData(userId: userId, value: userPassword)
        
        CoreDataManager.shared.addAccount(userId: userId, password: encrytedPassword, accountStatus: AccountState.Connected.rawValue, orderSource: OrderSource.Amazon.rawValue)
    }
    
}


