//  BSCSVScrapper.swift
//  OrderScrapper

import Foundation
import WebKit

class BSCSVScrapper: NSObject {
    private var webView: WKWebView
    private var scrapingMode: ScrapingMode
    private var reportConfig: ReportConfig!
    private var scraperListener: ScraperProgressListener
    private var account: Account!
    private var currentStep: Step!
    private var dateRange: DateRange!
    private var timerHandler: TimerHandler!
    private var param: BSHtmlScrapperParams?
    private var loginDetected = false
    private var bsScrapper: BSHtmlScrapper?

    init(webview: WKWebView, scrapingMode: ScrapingMode, scraperListener: ScraperProgressListener) {
        self.webView = webview
        self.scrapingMode = scrapingMode
        self.scraperListener = scraperListener
    }
    
    public func scrapeOrders(response: DateRange, account: Account, timerHandler: TimerHandler, param: BSHtmlScrapperParams?) {
        self.dateRange = response
        self.webView.navigationDelegate = self
        self.timerHandler = timerHandler
        self.reportConfig = parseReportConfig(dateRange: response)
        self.account = account
        
        if scrapingMode == .Background {
            self.loginDetected = false
            self.param = param
            self.bsScrapper = BSHtmlScrapper(params: param!)
            loadUrl()
        } else {
            evaluateJS(jsType: .dateRange, javascript: getOldestPossibleYear())
        }
    }
    
    private func loadUrl() {
        self.webView.navigationDelegate = self
        let url = URL(string: AppConstants.generateReportUrl)
        let urlRequest = URLRequest(url: url!)
        self.webView.load(urlRequest)
    }
    private func evaluateJS(jsType: JSInjectValue, javascript: String) {
        self.webView.evaluateJavaScript(javascript) {
            (response, error) in
            self.evaluateJSResult(jsType: jsType, response: (response, error))
            
            //Log events for JS injection
            var logEventAttributes:[String:String] = [:]
            var status: String
            if error == nil {
                status = EventStatus.Success
            } else {
                status = EventStatus.Failure
                print(AppConstants.tag, "evaluateJavaScript", error.debugDescription)
            }
            switch jsType {
            case .email:
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: status]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
            case .password:
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: status]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectPassword, eventAttributes: logEventAttributes)
            case .captcha:
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: status]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
            case .generateReport:
                self.timerHandler.startTimer(action: Actions.ReportGenerationJSCallback)
                //Logging event for report generation
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource:                    String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: status]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportGeneration, eventAttributes: logEventAttributes)
            case .downloadReport:
                self.timerHandler.stopTimer()
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource:                    String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: status]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportDownload, eventAttributes: logEventAttributes)
            case .dateRange, .identification, .error:break
            }
        }
    }
    
    private func evaluateJSResult(jsType: JSInjectValue, response: (Any?, Error?)) {
        //guard let self = self else { return }
        let (response, _) = response
        switch jsType {
        case .captcha,.downloadReport, .email, .generateReport, .identification, .password, .error: break
        case .dateRange:
            if let response = response {
                self.timerHandler.startTimer(action: Actions.GetOldestPossibleYearJSCallback)
                let strResult = response as! String
                if (!strResult.isEmpty) {
                    let year = Int(strResult) ?? 0
                    let startYear = Int(reportConfig.startYear)
                    let endYear = Int(reportConfig.endYear)
                    if year > startYear! {
                        reportConfig.startYear = String(year)
                        reportConfig.startDate = AppConstants.firstDayOfJan
                        reportConfig.startMonth =  AppConstants.monthJan
                        let startDate = AppConstants.firstDayOfJan + "-" + AppConstants.monthJan + "-" + String(year)
                        reportConfig.fullStartDate = DateUtils.getFormattedDate(dateStr: startDate)
                    }
                    if year > endYear! {
                        reportConfig.endYear = String(year)
                        let endDate = reportConfig.endDate + "-" + reportConfig.endMonth + "-" + String(year)
                        reportConfig.fullStartDate = DateUtils.getFormattedDate(dateStr: endDate)
                    }
                }
                self.injectGenerateReportJS()
            }
        }
    }
    private func getSubURL(from url: String, delimeter: String) -> String {
        if url.contains(delimeter) {
            return Utils.getSubUrl(url: url, delimeter: delimeter)
        }
        return url
    }
    private func navigateWith(url: URL?) {
        guard let url = url else { return }
        let urlString = url.absoluteString
        
        if scrapingMode == .Background {
            let loginSubURL = getSubURL(from: self.param!.configuration.login, delimeter: "/?")
            if ((urlString.contains(loginSubURL) || loginSubURL.contains(urlString)) && !loginDetected) {
                self.loginDetected = true
                self.param!.authenticator.authenticate(account: self.param!.account,
                                                       configurations: self.param!.configuration) { [weak self] authenticated, error in
                    guard let self = self else { return }
                    
                    if authenticated {
                        self.loadUrl()
                    } else {
                        if error?.errorMessage == "Captcha page loaded" || error?.errorMessage == "Other url loaded" {
                            let errorMessage = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: .authError, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.report)
                            self.bsScrapper!.onAuthenticationFailure(error: errorMessage)
                        } else {
                            // Call this method when only in scrapping mode is background
                            let errorMessage = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: .authError, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.report)
                            self.didFinishWith(error: errorMessage)
                        }
                    }
                }
            }
        }
        
        if (urlString.contains(AmazonURL.generateReport)) {
            evaluateJS(jsType: .dateRange, javascript: getOldestPossibleYear())
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            self.injectDownloadReportJS()
            self.currentStep = .downloadReport
            publishProgrssFor(step: .downloadReport)
            self.timerHandler.startTimer(action: Actions.DownloadReportJSInjection)
        } else if (urlString.contains(AmazonURL.reportSuccess)) {
            //No handling required
        } else {
            if scrapingMode == .Background {
                print("other url",urlString)
                let error = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: nil, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.report)
                bsScrapper!.onAuthenticationFailure(error: error)
            }
        }
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
    
    private func getOldestPossibleYear() -> String {
        return "(function() {var listOfYears = document.getElementById('report-year-start');" +
            "var oldestYear = 0;" +
            "for (i = 0; i < listOfYears.options.length; i++) {" +
            "if(!isNaN(listOfYears.options[i].value) && (listOfYears.options[i].value < oldestYear || oldestYear ==0))" +
            "{ oldestYear = listOfYears.options[i].value;}" +
            "} return oldestYear })()"
    }
    
    private func injectGenerateReportJS() {
        if let reportConfig = reportConfig {
            let js = "javascript:" +
                "document.getElementById('report-type').value = '" + AppConstants.amazonReportType + "';" +
                "document.getElementById('report-month-start').value = '" + reportConfig.startMonth + "';" +
                "document.getElementById('report-day-start').value = '" + reportConfig.startDate + "';" +
                "document.getElementById('report-year-start').value = '" + reportConfig.startYear + "';" +
                "document.getElementById('report-month-end').value = '" + reportConfig.endMonth + "';" +
                "document.getElementById('report-day-end').value = '" + reportConfig.endDate + "';" +
                "document.getElementById('report-year-end').value = '" + reportConfig.endYear + "';" +
                "document.getElementById('report-confirm').click()"
            evaluateJS(jsType: .generateReport, javascript: js)
        }
    }
    
    private func injectDownloadReportJS() {
        let js = "javascript:" +
            "document.getElementById(window['download-cell-'+new URLSearchParams(window.location.search).get(\"reportId\")].id).click()"
        evaluateJS(jsType: .downloadReport, javascript: js)
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
            self.scraperListener.onWebviewError(isError: true)
            return
        }
        let fileDownloader = FileDownloader()
        fileDownloader.downloadFile(fromURL: url, cookies: cookies) { success, tempURL in
            var logEventAttributes:[String:String] = [:]
            if success, let tempURL = tempURL {
                let fileName = FileHelper.getReportFileNameFromResponse(response)
                self.removePIIAttributes(fileName: fileName, fileURL: tempURL)
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: EventStatus.Success,
                                      EventConstant.FileName: fileName]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVDownload, eventAttributes: logEventAttributes)
                self.timerHandler.stopTimer()
            } else {
                self.updateOrderStatusFor(error: AppConstants.msgDownloadCSVFailed, accountStatus: self.account.accountState.rawValue)
                self.scraperListener.onWebviewError(isError: true)
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVDownload, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func removePIIAttributes(fileName: String, fileURL: URL) {
        self.currentStep = .parseReport
        publishProgrssFor(step: .parseReport)
        var logAPIEventAttributes:[String:String] = [:]
        let tempURL = FileHelper.getReportDownloadPath(fileName: "temp.csv", orderSource: .Amazon)
        _ = FileHelper.moveFileToPath(fromURL: fileURL, destinationURL: tempURL)
        
        _ = AmazonService.getPIIList() { response, error in
            guard let attributes = response else {
                self.updateOrderStatusFor(error: AppConstants.msgPIIAPIFailed, accountStatus: AccountState.Connected.rawValue)
                self.scraperListener.onWebviewError(isError: true)
                // Log event for PIIList API failure
                logAPIEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                         EventConstant.OrderSourceID: self.account.userID,
                                         EventConstant.ErrorReason: error.debugDescription,
                                         EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIPIIList, eventAttributes: logAPIEventAttributes)
                return
            }
            // Log event for PIIList API success
            logAPIEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                     EventConstant.OrderSourceID: self.account.userID,
                                     EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIPIIList, eventAttributes: logAPIEventAttributes)
            
            let scrapper = PIIScrapper(fileURL: tempURL, fileName: fileName, orderSource: .Amazon)
            var logEventAttributes:[String:String] = [:]
            scrapper.scrapPII(attributes: attributes) { destinationURL, error in
                guard let destinationURL = destinationURL else {
                    self.updateOrderStatusFor(error: AppConstants.msgCSVParsingFailed, accountStatus: self.account.accountState.rawValue)
                    self.scraperListener.onWebviewError(isError: true)  
                    
                    //Log event for error in parsing
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: self.account.userID,
                                          EventConstant.FileName: fileName,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVPParse, eventAttributes: logEventAttributes)
                    print(AppConstants.tag, "removePIIAttributes", error.debugDescription)
                    return
                }
                self.uploadCSVFile(fileURL: destinationURL)
                
                //Log event for successful parsing
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.FileName: fileName,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVPParse, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func uploadCSVFile(fileURL url: URL) {
        self.currentStep = .uploadReport
        publishProgrssFor(step: .uploadReport)
        //let reportConfig = reportConfig
        let fromDate = reportConfig.fullStartDate!
        let toDate = reportConfig.fullEndDate!
        _ = AmazonService.uploadFile(fileURL: url,
                                     amazonId: self.account.userID,
                                     fromDate: fromDate, toDate: toDate) { response, error in
            var logEventAttributes:[String:String] = [:]
            if response != nil {
                self.currentStep = .complete
                self.publishProgrssFor(step: .complete)
                self.addUserAccountInDB()
                
                if self.scrapingMode == .Background {
                    self.logEvents(message: AppConstants.msgUploadCSVSuccess, section: SectionType.orderUpload.rawValue, status: EventState.success.rawValue, type: FailureTypes.other.rawValue)
                } else {
                    self.logEvents(message: AppConstants.msgUploadCSVSuccess, section: SectionType.connection.rawValue, status: EventState.success.rawValue, type: FailureTypes.other.rawValue)
                }
                //Log event for successful uploading of csv
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
                
                //Log event for connect account
                var logConnectAccountEventAttributes:[String:String] = [:]
                logConnectAccountEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                                    EventConstant.OrderSourceID: self.account.userID,
                                                    EventConstant.Status: EventStatus.Connected]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
            } else {
                self.scraperListener.onWebviewError(isError: true)
                _ = AmazonService.updateStatus(amazonId: self.account.userID,
                                               status: AccountState.Connected.rawValue, message: AppConstants.msgCSVUploadFailed, orderStatus: OrderStatus.Failed.rawValue) { response, error in
                    //Todo
                }
                
                if self.scrapingMode == .Background {
                    self.logEvents(message: AppConstants.msgCSVUploadFailed, section: SectionType.orderUpload.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue)
                } else {
                    self.logEvents(message: AppConstants.msgCSVUploadFailed, section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue)
                }
                
                //Log event for failure in csv upload
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
            }
            //Delete downloaded file even if file uploading is successful or failure
            FileHelper.clearDirectory(orderSource: .Amazon)
        }
    }
    
    private func updateOrderStatusFor(error: String, accountStatus: String) {
        let amazonId = self.account.userID
        _ = AmazonService.updateStatus(amazonId: amazonId,
                                       status: accountStatus,
                                       message: error,
                                       orderStatus: OrderStatus.Failed.rawValue) { response, error in
        }
    }
    
    /*
     * add user account details in DB
     */
    private func addUserAccountInDB() {
        let account = self.account as! UserAccountMO
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: AccountState.Connected.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    /*
     * get progress value in the range 0 to 1 from step number
     **/
    private func publishProgrssFor(step : Step) {
        let progressValue = Float(step.rawValue) / AppConstants.numberOfSteps
        var stepMessage: String
        
        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
        case .generateReport:
            stepMessage = Utils.getString(key: Strings.Step2)
        case .downloadReport:
            stepMessage = Utils.getString(key: Strings.Step3)
        case .parseReport:
            stepMessage = Utils.getString(key: Strings.Step4)
        case .uploadReport:
            stepMessage = Utils.getString(key: Strings.Step5)
        case .complete:
            stepMessage = Utils.getString(key: Strings.Step6)
        }
        
        self.scraperListener.updateProgressValue(progressValue: progressValue)
        self.scraperListener.updateStepMessage(stepMessage: stepMessage)
        self.scraperListener.onCompletion(isComplete: (step == .complete))
    }
    
    private func didFinishWith(error: ASLException) {
        do {
            try CoreDataManager.shared.updateUserAccount(userId: self.param!.account.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.param!.account.panelistID)
        } catch {
            print("updateAccountWithExceptionState")
        }
        _ = AmazonService.updateStatus(amazonId: self.param!.account.userID, status: AccountState.ConnectedButException.rawValue, message: AppConstants.msgAuthError, orderStatus: OrderStatus.Failed.rawValue) { response, error in
        }
        self.param!.listener.onHtmlScrappingFailure(error: error)
    }
    
    private func logEvents(message: String, section: String, status: String, type: String) {
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: section, type: type , status: status, message: message, fromDate: self.dateRange!.fromDate!, toDate: self.dateRange!.toDate!, scrappingType: ScrappingType.report.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLogs) { response, error in
                //TODO
        }
    }
}

extension BSCSVScrapper: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.navigateWith(url: webView.url)
        print("## didFinish " + webView.url!.absoluteString)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if (self.shouldIntercept(navigationResponse: navigationResponse.response)) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                self.intercept(navigationResponse: navigationResponse.response, cookies: cookies)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,"An error occurred during navigation", error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,"An error occurred during the early navigation process", error.localizedDescription)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print(AppConstants.tag, "webViewWebContentProcessDidTerminate()")
    }
}
