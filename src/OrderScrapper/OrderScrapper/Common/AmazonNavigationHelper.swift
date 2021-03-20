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

private enum Step {
    case authentication, generateReport, downloadReport, parseCSV, uploadReport, complete
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
    
    // MARK:- NavigationHelper Methods
    func navigateWith(url: URL?) {
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
            self.getDateRange()
            self.viewModel.progressValue.send(getProgressPercentage(step: .generateReport))
        } 
    }
    
    func shouldIntercept(navigationResponse response: URLResponse) -> Bool {
        if let mimeType = response.mimeType {
            let result = mimeType.compare("text/csv")
            return result == .orderedSame
        }
        return false
    }
    
    func intercept(navigationResponse response: URLResponse, cookies: [HTTPCookie]) {
        guard let url = response.url else {
            self.viewModel.webviewError.send(true)
            return
        }
        
        let fileDownloader = FileDownloader()
        fileDownloader.downloadReportFile(fromURL: url, cookies: cookies) { success, tempURL in
            if success, let tempURL = tempURL {
                let fileName = FileHelper.getReportFileNameFromResponse(response)
                self.removePIIAttributes(fileName: fileName, fileURL: tempURL)
            } else {
                self.viewModel.webviewError.send(true)
            }
        }
    }
    
    // MARK:- Private Methods
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
    
    private func parseReportConfig(dateRange: DateRange) -> ReportConfig {
        let startDateComponents = DateUtils.parseDateComponents(fromDate: dateRange.fromDate!,
                                                                dateFormat: DateUtils.APIDateFormat)
        
        let endDateComponents = DateUtils.parseDateComponents(fromDate: dateRange.toDate!,
                                                              dateFormat: DateUtils.APIDateFormat)
        
        debugPrint("Start Date Comps: ", startDateComponents)
        debugPrint("End Date Comps: ", endDateComponents)
        
        var reportConfig = ReportConfig()
        reportConfig.startDate = String(startDateComponents.day!)
        reportConfig.startMonth = String(startDateComponents.month!)
        reportConfig.startYear = String(startDateComponents.year!)
        reportConfig.endDate = String(endDateComponents.day!)
        reportConfig.endMonth = String(endDateComponents.month!)
        reportConfig.endYear = String(endDateComponents.year!)
        reportConfig.fullStartDate = dateRange.fromDate!
        reportConfig.fullEndDate = dateRange.toDate!
        
        debugPrint("Report Config: ", reportConfig)
        
        return reportConfig
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
        case .complete:
            progressValue = 6
        }
        return progressValue/AppConstants.numberOfSteps
    }
    
    private func getDateRange() {
        _ = AmazonService.getDateRange(amazonId: self.viewModel.userEmail!) { response, error in
            if let response = response {
                let reportConfig = self.parseReportConfig(dateRange: response)
                self.viewModel.reportConfig = reportConfig
                self.injectGenerateReportJS()
            } else {
                self.viewModel.webviewError.send(true)
            }
        }
    }
    
    private func removePIIAttributes(fileName: String, fileURL: URL) {
        self.viewModel.progressValue.send(getProgressPercentage(step: .parseCSV))
        
        let tempURL = FileHelper.getReportDownloadPath(fileName: "temp.csv", orderSource: .Amazon)
        _ = FileHelper.moveFileToPath(fromURL: fileURL, destinationURL: tempURL)
        
        _ = AmazonService.getPIIList() { response, error in
            guard let attributes = response else {
                self.viewModel.webviewError.send(true)
                return
            }
            
            let scrapper = PIIScrapper(fileURL: tempURL, fileName: fileName, orderSource: .Amazon)
            scrapper.scrapPII(attributes: attributes) { destinationURL, error in
                guard let destinationURL = destinationURL else {
                    self.viewModel.webviewError.send(true)
                    return
                }
                self.uploadCSVFile(fileURL: destinationURL)
            }
        }
    }
    
    private func uploadCSVFile(fileURL url: URL) {
        self.viewModel.progressValue.send(getProgressPercentage(step: .uploadReport))
        
        let reportConfig = self.viewModel.reportConfig!
        let fromDate = reportConfig.fullStartDate!
        let toDate = reportConfig.fullEndDate!
        
        _ = AmazonService.uploadFile(fileURL: url,
                                     amazonId: self.viewModel.userEmail!,
                                     fromDate: fromDate, toDate: toDate) { response, error in
            if response != nil {
                self.viewModel.progressValue.send(self.getProgressPercentage(step: .complete))
            } else {
                self.viewModel.webviewError.send(true)
            }
        }
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
