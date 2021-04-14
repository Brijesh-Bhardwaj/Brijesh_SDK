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
            
            //Log event for connect account
            var logConnectAccountEventAttributes:[String:String] = [:]
            logConnectAccountEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.Status: EventStatus.Connected]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
        } else if (urlString.contains(AmazonURL.authApproval)
                    || urlString.contains(AmazonURL.twoFactorAuth)) {
            self.viewModel.showWebView.send(true)
            //Log event for authentication approval or two factor authentication
            var logAuthEventAttributes:[String:String] = [:]
            var eventType: String
            if urlString.contains(AmazonURL.authApproval) {
                eventType = EventType.JSDetectedAuthApproval
            } else {
                eventType = EventType.JSDetectedTwoFactorAuth
            }
            logAuthEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: eventType, eventAttributes: logAuthEventAttributes)
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            self.injectDownloadReportJS()
            publishProgrssFor(step: .downloadReport)
        } else if (urlString.contains(AmazonURL.generateReport)) {
            let userAccountState = self.viewModel.userAccount.accountState
            if userAccountState == AccountState.NeverConnected {
                let userId = self.viewModel.userAccount.userID
                _ = AmazonService.registerConnection(amazonId: userId, status: AccountState.NeverConnected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue) { response, error in
                    if let response = response  {
                        //On authentication add user account details to DB
                        self.viewModel.userAccount.isFirstConnectedAccount = response.firstaccount
                        self.getDateRange()
                        self.publishProgrssFor(step: .generateReport)
                    } else {
                        self.viewModel.authError.send((isError: true, errorMsg: error!))
                    }
                }
            } else {
                //On authentication add user account details to DB
                self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                self.addUserAccountInDB()
                self.getDateRange()
                self.publishProgrssFor(step: .generateReport)
            }
        } else {
            //Log event for getting other url
            var logOtherUrlEventAttributes:[String:String] = [:]
            logOtherUrlEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectOtherURL, eventAttributes: logOtherUrlEventAttributes)
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
            var logEventAttributes:[String:String] = [:]
            if success, let tempURL = tempURL {
                let fileName = FileHelper.getReportFileNameFromResponse(response)
                self.removePIIAttributes(fileName: fileName, fileURL: tempURL)
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.Status: EventStatus.Success,
                                      EventConstant.FileName: fileName]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVDownload, eventAttributes: logEventAttributes)
            } else {
                self.updateOrderStatusFor(error: AppConstants.msgDownloadCSVFailed, accountStatus: self.viewModel.userAccount.accountState.rawValue)
                self.viewModel.webviewError.send(true)
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVDownload, eventAttributes: logEventAttributes)
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
        var logEventAttributes:[String:String] = [:]
        _ = AmazonService.getDateRange(amazonId: self.viewModel.userAccount.userID) { response, error in
            if let response = response {
                if response.enableScraping {
                    let reportConfig = self.parseReportConfig(dateRange: response)
                    self.viewModel.reportConfig = reportConfig
                    self.viewModel.jsPublisher.send((.dateRange, self.getOldestPossibleYear()))
                    self.setJSInjectionResultSubscriber()
                } else {
                    self.updateAccountStatusToConnected(orderStatus: OrderStatus.None.rawValue)
                    self.addUserAccountInDB()
                    self.viewModel.disableScrapping.send(true)
                }
                //Logging event for successful date range API call
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            } else {
                self.updateOrderStatusFor(error: AppConstants.msgDateRangeAPIFailed, accountStatus: self.viewModel.userAccount.accountState.rawValue)
                self.viewModel.webviewError.send(true)
                //Log event for failure of date range API call
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func setJSInjectionResultSubscriber() {
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
                                let startDate = AppConstants.firstDayOfJan + "-" + AppConstants.monthJan + "-" + String(year)
                                self.viewModel.reportConfig?.fullStartDate = DateUtils.getFormattedDate(dateStr: startDate)
                            }
                            if year > endYear! {
                                self.viewModel.reportConfig?.endYear = String(year)
                                let endDate = self.viewModel.reportConfig!.endDate + "-" + self.viewModel.reportConfig!.endMonth + "-" + String(year)
                                self.viewModel.reportConfig?.fullStartDate = DateUtils.getFormattedDate(dateStr: endDate)
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
        var logAPIEventAttributes:[String:String] = [:]
        let tempURL = FileHelper.getReportDownloadPath(fileName: "temp.csv", orderSource: .Amazon)
        _ = FileHelper.moveFileToPath(fromURL: fileURL, destinationURL: tempURL)
        
        _ = AmazonService.getPIIList() { response, error in
            guard let attributes = response else {
                self.updateOrderStatusFor(error: AppConstants.msgPIIAPIFailed, accountStatus: self.viewModel.userAccount.accountState.rawValue)
                self.viewModel.webviewError.send(true)
                // Log event for PIIList API failure
                logAPIEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                         EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                         EventConstant.ErrorReason: error.debugDescription,
                                         EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIPIIList, eventAttributes: logAPIEventAttributes)
                return
            }
            // Log event for PIIList API success
            logAPIEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIPIIList, eventAttributes: logAPIEventAttributes)
            
            let scrapper = PIIScrapper(fileURL: tempURL, fileName: fileName, orderSource: .Amazon)
            var logEventAttributes:[String:String] = [:]
            scrapper.scrapPII(attributes: attributes) { destinationURL, error in
                guard let destinationURL = destinationURL else {
                    self.updateOrderStatusFor(error: AppConstants.msgCSVParsingFailed, accountStatus: self.viewModel.userAccount.accountState.rawValue)
                    self.viewModel.webviewError.send(true)
                    
                    //Log event for error in parsing
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.FileName: fileName,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVPParse, eventAttributes: logEventAttributes)
                    return
                }
                self.uploadCSVFile(fileURL: destinationURL)
                
                //Log event for successful parsing
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.FileName: fileName,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVPParse, eventAttributes: logEventAttributes)
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
            var logEventAttributes:[String:String] = [:]
            if response != nil {
                self.publishProgrssFor(step: .complete)
                self.addUserAccountInDB()
                //Log event for successful uploading of csv
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
            } else {
                self.viewModel.webviewError.send(true)
                
                _ = AmazonService.updateStatus(amazonId: self.viewModel.userAccount.userID,
                                               status: AccountState.NeverConnected.rawValue, message: AppConstants.msgCSVUploadFailed, orderStatus: OrderStatus.Failed.rawValue) { response, error in
                    //Todo
                }
                
                //Log event for failure in csv upload
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
            }
            //Delete downloaded file even if file uploading is successful or failure
            FileHelper.clearDirectory(orderSource: .Amazon)
        }
    }
    
    /*
     * add user account details in DB
     */
    private func addUserAccountInDB() {
        let account = self.viewModel.userAccount as! UserAccountMO
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: AccountState.Connected.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    private func updateOrderStatusFor(error: String, accountStatus: String) {
        let amazonId = self.viewModel.userAccount.userID
        _ = AmazonService.updateStatus(amazonId: amazonId,
                                       status: accountStatus,
                                       message: error,
                                       orderStatus: OrderStatus.Failed.rawValue) { response, error in
        }
    }
    
    private func updateAccountStatusToConnected(orderStatus: String) {
        let amazonId = self.viewModel.userAccount.userID
        _ = AmazonService.updateStatus(amazonId: amazonId,
                                       status: AccountState.Connected.rawValue,
                                       message: AppConstants.msgConnected,
                                       orderStatus: orderStatus) { response, error in
        }
    }
}
