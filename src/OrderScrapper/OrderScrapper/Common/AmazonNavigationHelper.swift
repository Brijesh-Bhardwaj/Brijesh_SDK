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

private enum Step: Int16 {
    case authentication = 1,
         generateReport = 2,
         downloadReport = 3,
         parseReport = 4,
         uploadReport = 5,
         complete = 6
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
            publishProgrssFor(step: .authentication)
        } else if (urlString.contains(AmazonURL.authApproval)
                    || urlString.contains(AmazonURL.twoFactorAuth)) {
            self.viewModel.showWebView.send(true)
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            self.injectDownloadReportJS()
            publishProgrssFor(step: .downloadReport)
        } else if (urlString.contains(AmazonURL.generateReport)) {
            //On authentication add user account details to DB
            self.addUserAccountInDB()
            self.getDateRange()
            publishProgrssFor(step: .generateReport)
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
                "document.getElementById('report-type').value = '" + AppConstants.amazonReportType + "';" +
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
    private func publishProgrssFor(step : Step) {
        let progressValue = Float(step.rawValue) / AppConstants.numberOfSteps
        
        var progressMessage: String?
        var headerMessage: String?
        var stepMessage: String

        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
            headerMessage = Utils.getString(key: Strings.HeadingConnectAmazonAccount)
            progressMessage = Utils.getString(key: Strings.HeadingConnectingAmazonAccount)
        case .generateReport:
            stepMessage = Utils.getString(key: Strings.Step2)
            headerMessage = Utils.getString(key: Strings.HeadingFetchingReceipts)
            progressMessage = Utils.getString(key: Strings.HeadingFetchingYourReceipts)
        case .downloadReport:
            stepMessage = Utils.getString(key: Strings.Step3)
        case .parseReport:
            stepMessage = Utils.getString(key: Strings.Step4)
        case .uploadReport:
            stepMessage = Utils.getString(key: Strings.Step5)
        case .complete:
            stepMessage = Utils.getString(key: Strings.Step6)
        }
        
        self.viewModel.progressValue.send(progressValue)
        self.viewModel.stepMessage.send(stepMessage)
        self.viewModel.completionPublisher.send(step == .complete)
        
        if let progressMessage = progressMessage {
            self.viewModel.progressMessage.send(progressMessage)
        }
        
        if let headerMessage = headerMessage {
            self.viewModel.headingMessage.send(headerMessage)
        }
    }
    
    private func getDateRange() {
        _ = AmazonService.getDateRange(amazonId: self.viewModel.userAccount.userID) { response, error in
            if let response = response {
                let reportConfig = self.parseReportConfig(dateRange: response)
                self.viewModel.reportConfig = reportConfig
                
                self.viewModel.jsPublisher.send((.dateRange, self.getOldestPossibleYear()))
                self.callback()
            } else {
                self.viewModel.webviewError.send(true)
            }
        }
    }
    
    private func callback() {
        self.jsResultSubscriber = viewModel.jsResultPublisher.receive(on: RunLoop.main)
            .sink(receiveValue: { (injectValue, result) in
                let (response, _) = result
                switch injectValue {
                case .captcha,.downloadReport, .email, .generateReport, .identification, .password, .error: break
                case .dateRange:
                    if let response = response {
                        let strResult = response as! String
                        if (!strResult.isEmpty) {
                            let year = Int(strResult) ?? 0
                            let startYear = Int(self.viewModel.reportConfig!.startYear)
                            let endYear = Int(self.viewModel.reportConfig!.endYear)

                            if year > startYear! {
                                self.viewModel.reportConfig?.startYear = String(year)
                                self.viewModel.reportConfig?.startDate = AppConstants.firstDayOfJan
                                self.viewModel.reportConfig?.startMonth =  AppConstants.monthJan
                            }
                            if year > endYear! {
                                self.viewModel.reportConfig?.endYear = String(year)
                            }
                        }
                        self.injectGenerateReportJS()
                    }
                }
            })
        
    }
    
    private func getOldestPossibleYear() -> String {
        return "(function() {var listOfYears = document.getElementById('report-year-start');" +
                "var oldestYear = 0;" +
                "for (i = 0; i < listOfYears.options.length; i++) {" +
                "if(!isNaN(listOfYears.options[i].value) && (listOfYears.options[i].value < oldestYear || oldestYear ==0))" +
                "{ oldestYear = listOfYears.options[i].value;}" +
                "} return oldestYear })()"
    }
    
    private func removePIIAttributes(fileName: String, fileURL: URL) {
        publishProgrssFor(step: .parseReport)
        
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
        publishProgrssFor(step: .uploadReport)
        
        let reportConfig = self.viewModel.reportConfig!
        let fromDate = reportConfig.fullStartDate!
        let toDate = reportConfig.fullEndDate!
        
        _ = AmazonService.uploadFile(fileURL: url,
                                     amazonId: self.viewModel.userAccount.userID,
                                     fromDate: fromDate, toDate: toDate) { response, error in
            if response != nil {
                self.publishProgrssFor(step: .complete)
            } else {
                self.viewModel.webviewError.send(true)
            }
        }
    }
    
    /*
     * add user account details in DB
     */
    private func addUserAccountInDB() {
        let account = self.viewModel.userAccount as! UserAccountMO
        
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: AccountState.Connected.rawValue, orderSource: account.orderSource)
    }
}
