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
    var fetchRequestSource: FetchRequestSource!
    var scrapeTimer = BSTimer()
    var scrapingTimer: Int64 = 0
    
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
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                guard let self = self else {return}
                self.evaluateJS(jsType: .dateRange, javascript: self.getOldestPossibleYear())
            }
        }
    }
    
    private func loadUrl() {
        self.webView.navigationDelegate = self
        let url = URL(string: AppConstants.generateReportUrl)
        let urlRequest = URLRequest(url: url!)
        DispatchQueue.main.async {
            self.webView.load(urlRequest)
        }
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_CSVScrapper_loadUrl() \(url)")
    }
    private func evaluateJS(jsType: JSInjectValue, javascript: String) {
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(javascript) { [weak self]
                (response, error) in
                guard let self = self else { return }
                self.evaluateJSResult(jsType: jsType, response: (response, error))
                
                //Log events for JS injection
                var logEventAttributes:[String:String] = [:]
                var commonEventAttributes:[String:String] = [:]
                
                commonEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                                         EventConstant.OrderSourceID: self.account.userID,
                                         EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                         EventConstant.ScrappingType: ScrappingType.report.rawValue]
                
                var status: String
                if error == nil {
                    status = EventStatus.Success
                } else {
                    status = EventStatus.Failure
                    print(AppConstants.tag, "evaluateJavaScript", error.debugDescription)
                    logEventAttributes[EventConstant.ErrorReason] = error.debugDescription
                }
                logEventAttributes[EventConstant.Status] = status
                logEventAttributes.merge(dict: commonEventAttributes)
                switch jsType {
                case .email:
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
                case .password:
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectPassword, eventAttributes: logEventAttributes)
                case .captcha:
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                case .generateReport:
                    self.timerHandler.startTimer(action: Actions.ReportGenerationJSCallback)
                    //Logging event for report generation
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportGeneration, eventAttributes: logEventAttributes)
                case .downloadReport:
                    self.timerHandler.stopTimer()
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportDownload, eventAttributes: logEventAttributes)
                case .dateRange, .identification, .error:break
                }
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
                    if let startYear = startYear {
                        if year > startYear {
                            reportConfig.startYear = String(year)
                            reportConfig.startDate = AppConstants.firstDayOfJan
                            reportConfig.startMonth =  AppConstants.monthJan
                            let startDate = AppConstants.firstDayOfJan + "-" + AppConstants.monthJan + "-" + String(year)
                            reportConfig.fullStartDate = DateUtils.getFormattedDate(dateStr: startDate)
                        }
                    }
                    if let endYear = endYear {
                        if year > endYear {
                            reportConfig.endYear = String(year)
                            let endDate = reportConfig.endDate + "-" + reportConfig.endMonth + "-" + String(year)
                            reportConfig.fullStartDate = DateUtils.getFormattedDate(dateStr: endDate)
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                    guard let self = self else {return}
                    //start timers
                    self.scrapeTimer.start()
                    self.injectGenerateReportJS()
                }
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
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                              EventConstant.OrderSourceID: self.account.userID,
                              EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                              EventConstant.URL: urlString,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UrlLoadedReportScrapping, eventAttributes: logEventAttributes)
        
        if scrapingMode == .Background {
            let loginSubURL = getSubURL(from: self.param!.configuration.login, delimeter: "/?")
            if ((urlString.contains(loginSubURL) || loginSubURL.contains(urlString)) && !loginDetected) {
                self.loginDetected = true
                self.param!.authenticator.authenticate(account: self.param!.account, configurations: self.param!.configuration, scrapingMode: ScrapingMode.Background.rawValue) { [weak self] authenticated, error in
                    guard let self = self else { return }
                    
                    if authenticated {
                        self.loadUrl()
                    } else {
                        if error?.errorType == ErrorType.authError && error?.errorEventLog == FailureTypes.authentication {
                            let errorMessage = ASLException(errorMessages: error!.errorMessage, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                                self.didFinishWith(error: errorMessage)
                                var logEventAttributes:[String:String] = [:]
                                logEventAttributes = [EventConstant.ErrorReason: error!.errorMessage,
                                EventConstant.Status: EventStatus.Failure]
                                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
                        } else if error?.errorMessage == AppConstants.AmazonErrorMessage {
                            let errorMessage = ASLException(errorMessages: error!.errorMessage, errorTypes: .authError, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.html)
                            self.bsScrapper!.onAmazonAuthFailure(error: errorMessage)
                        } else  {
                            let errorMessage = ASLException(errorMessages: error!.errorMessage, errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                            self.bsScrapper!.onAuthenticationFailure(error: errorMessage, orderSource: self.account.source)
                        }
                    }
                }
            }
        }
        
        if (urlString.contains(AmazonURL.downloadReport)
                && urlString.contains(AmazonURL.reportID)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                guard let self = self else {return}
                self.injectDownloadReportJS()
                self.currentStep = .downloadReport
                self.publishProgrssFor(step: .downloadReport)
                    self.timerHandler.startTimer(action: Actions.DownloadReportJSInjection)
            }
        } else if (urlString.contains(AmazonURL.reportSuccess)) {
            //No handling required
        } else if (urlString.contains(AmazonURL.generateReport) || urlString.contains(AmazonURL.generatereportURL)) {
            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_CSVScrapper_generate_report_url \(urlString)")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                guard let self = self else {return}
                self.checkCurrentReportPage(key: AppConstants.isReportReady)
            }
        } else {
            if scrapingMode == .Background {
                print("other url",urlString)
                
                var logOtherUrlEventAttributes:[String:String] = [:]
                logOtherUrlEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.PanelistID: self.account.panelistID,
                                              EventConstant.OrderSourceID: self.account.userID,
                                              EventConstant.ScrappingMode: scrapingMode.rawValue,
                                              EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                              EventConstant.Status: EventStatus.Success,
                                              EventConstant.URL: urlString]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepOtherURLLoaded, eventAttributes: logOtherUrlEventAttributes)

                
                let error = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: nil, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.report)
                bsScrapper!.onAuthenticationFailure(error: error, orderSource: self.account.source)
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
        var getOldestPossibleYear = ""
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getOldestPossibleYear) { script in
            if !script.isEmpty {
                getOldestPossibleYear = script
            } else {
                if self.scrapingMode == .Background {
                    let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "getOldestPossibleYear for amazon", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                    self.bsScrapper!.onAuthenticationFailure(error: errorMessage, orderSource: self.account.source)
                } else {
                    self.logEvents(message: Strings.ErrorScriptNotFound + "getOldestPossibleYear for amazon", section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                    let error = ASLException(errorMessage: Strings.ErrorScriptNotFound + "getOldestPossibleYear for amazon", errorType: .authError)
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
            }
        }
        return getOldestPossibleYear
    }
    
    private func injectGenerateReportJS() {
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getGenerateReportScript) { script in
            if !script.isEmpty {
                if let reportConfig = self.reportConfig {
                    let script = script.replacingOccurrences(of: "$ generateReport.startMonth $", with: reportConfig.startMonth).replacingOccurrences(of: "$ generateReport.startDay $", with: reportConfig.startDate).replacingOccurrences(of: "$ generateReport.startYear $", with: reportConfig.startYear).replacingOccurrences(of: "$ generateReport.endMonth $", with: reportConfig.endMonth).replacingOccurrences(of: "$ generateReport.endDay $", with: reportConfig.endDate).replacingOccurrences(of: "$ generateReport.endYear $", with: reportConfig.endYear)
                    print(script)
                    self.evaluateJS(jsType: .generateReport, javascript: script)
                }
            } else {
                if self.scrapingMode == .Background {
                    let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "injectGenerateReportJS for amazon", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                    FirebaseAnalyticsUtil.logSentryError(error: errorMessage)
                    self.bsScrapper!.onAuthenticationFailure(error: errorMessage, orderSource: self.account.source)
                } else {
                    self.logEvents(message: Strings.ErrorScriptNotFound + "injectGenerateReportJS for amazon", section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                    let error = ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectGenerateReportJS for amazon", errorType: .authError)
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
            }
        }
    }
    
    private func injectDownloadReportJS() {
         self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getDownloadReport) { script in
            if !script.isEmpty {
                self.evaluateJS(jsType: .downloadReport, javascript: script)
            } else {
                if self.scrapingMode == .Background {
                    let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "injectDownloadReportJS for amazon", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                    FirebaseAnalyticsUtil.logSentryError(error: errorMessage)
                    self.bsScrapper!.onAuthenticationFailure(error: errorMessage, orderSource: self.account.source)
                } else {
                    self.logEvents(message: Strings.ErrorScriptNotFound + "injectDownloadReportJS for amazon", section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                    let error = ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectDownloadReportJS for amazon", errorType: .authError)
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
            }
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
            self.scraperListener.onWebviewError(isError: true)
            return
        }
        let fileDownloader = FileDownloader()
        fileDownloader.downloadFile(fromURL: url, cookies: cookies) { success, tempURL in
            var logEventAttributes:[String:String] = [:]
            if success, let tempURL = tempURL {
                self.scrapingTimer = self.scrapeTimer.stopTimer()
                let fileName = FileHelper.getReportFileNameFromResponse(response)
                self.removePIIAttributes(fileName: fileName, fileURL: tempURL)
                
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.PanelistID: self.account.panelistID,
                                      EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                      EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                      EventConstant.Status: EventStatus.Success,
                                      EventConstant.FileName: fileName]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderCSVDownload, eventAttributes: logEventAttributes)
                self.timerHandler.stopTimer()
            } else {
                self.updateOrderStatusFor(error: AppConstants.msgDownloadCSVFailed, accountStatus: self.account.accountState.rawValue)
                self.scraperListener.onWebviewError(isError: true)
                
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.PanelistID: self.account.panelistID,
                                      EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                      EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionDownloadingCSVFile, eventAttributes: logEventAttributes)
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
                logAPIEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                         EventConstant.OrderSourceID: self.account.userID,
                                         EventConstant.PanelistID: self.account.panelistID,
                                         EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                         EventConstant.ErrorReason: error.debugDescription,
                                         EventConstant.EventName: EventType.PIIDetailsAPIFailed,
                                         EventConstant.Status: EventStatus.Failure]
                if let error = error {
                    self.sendServicesDownCallback(error: error)
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logAPIEventAttributes, error: error)
                } else {
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.PIIDetailsAPIFailed, eventAttributes: logAPIEventAttributes)
                }
                return
            }
            // Log event for PIIList API success
            var json: String
            do {
                let jsonData = try JSONEncoder().encode(response)
                json = String(data: jsonData, encoding: .utf8)!
            } catch {
                json = AppConstants.ErrorInJsonEncoding
            }
            logAPIEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                     EventConstant.OrderSourceID: self.account.userID,
                                     EventConstant.PanelistID: self.account.panelistID,
                                     EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                     EventConstant.Data: json,
                                     EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIPIIList, eventAttributes: logAPIEventAttributes)
            
            let scrapper = PIIScrapper(fileURL: tempURL, fileName: fileName, orderSource: .Amazon)
            var logEventAttributes:[String:String] = [:]
            scrapper.scrapPII(attributes: attributes) { destinationURL, error in
                guard let destinationURL = destinationURL else {
                    self.updateOrderStatusFor(error: AppConstants.msgCSVParsingFailed, accountStatus: self.account.accountState.rawValue)
                    self.scraperListener.onWebviewError(isError: true)  
                    
                    //Log event for error in parsing
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.OrderSourceID: self.account.userID,
                                          EventConstant.PanelistID: self.account.panelistID,
                                          EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                          EventConstant.FileName: fileName,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.Status: EventStatus.Failure]
                    
                    if let error = error {
                        logEventAttributes[EventConstant.EventName] = EventType.ExceptionWhileUpdatingCSVFile
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileUpdatingCSVFile, eventAttributes: logEventAttributes)
                    }
                    print(AppConstants.tag, "removePIIAttributes", error.debugDescription)
                    return
                }
                self.uploadCSVFile(fileURL: destinationURL)
                
                //Log event for successful parsing
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.PanelistID: self.account.panelistID,
                                      EventConstant.ScrappingMode: self.scrapingMode.rawValue,
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
        let scrapeTimer = String(self.scrapingTimer)
        _ = AmazonService.uploadFile(fileURL: url,
                                     platformId: self.account.userID,
                                     fromDate: fromDate, toDate: toDate, orderSource: OrderSource.Amazon.value, scrapeTime: scrapeTimer) { response, error in
            var logEventAttributes:[String:String] = [:]
            if response != nil {
                self.currentStep = .complete
                self.publishProgrssFor(step: .complete)
                UserDefaults.standard.setValue(0, forKey: Strings.OnAuthenticationChallenegeRetryCount)
                
                if self.scrapingMode == .Background {
                    self.logEvents(message: AppConstants.msgUploadCSVSuccess, section: SectionType.orderUpload.rawValue, status: EventState.success.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
                } else {
                    self.logEvents(message: AppConstants.msgUploadCSVSuccess, section: SectionType.connection.rawValue, status: EventState.success.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                }
                //Log event for successful uploading of csv
                logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.account.userID,
                                      EventConstant.PanelistID: self.account.panelistID,
                                      EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
                
                //Log event for connect account
                var logConnectAccountEventAttributes:[String:String] = [:]
                logConnectAccountEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                    EventConstant.OrderSourceID: self.account.userID,
                                                    EventConstant.PanelistID: self.account.panelistID,
                                                    EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
            } else {
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback(error: error)
                } else {
                    self.scraperListener.onWebviewError(isError: true)
                    _ = AmazonService.updateStatus(platformId: self.account.userID,
                                                   status: AccountState.Connected.rawValue, message: AppConstants.msgCSVUploadFailed, orderStatus: OrderStatus.Failed.rawValue, orderSource: OrderSource.Amazon.value) { response, error in
                        self.sendServicesDownCallback(error: error)
                    }
                    
                    if self.scrapingMode == .Background {
                        self.logEvents(message: AppConstants.msgCSVUploadFailed, section: SectionType.orderUpload.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Background.rawValue)
                    } else {
                        self.logEvents(message: AppConstants.msgCSVUploadFailed, section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                    }
                    
                    //Log event for failure in csv upload
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.OrderSourceID: self.account.userID,
                                          EventConstant.PanelistID: self.account.panelistID,
                                          EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                                          EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.Status: EventStatus.Failure]
                    if let error = error {
                        logEventAttributes[EventConstant.EventName] = EventType.UploadReportAPIFailed
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIUploadReport, eventAttributes: logEventAttributes)
                    }
                }
                //Delete downloaded file even if file uploading is successful or failure
                FileHelper.clearDirectory(orderSource: .Amazon)
            }
        }
    }
    private func updateOrderStatusFor(error: String, accountStatus: String) {
        let amazonId = self.account.userID
        _ = AmazonService.updateStatus(platformId: amazonId,
                                       status: accountStatus,
                                       message: error,
                                       orderStatus: OrderStatus.Failed.rawValue, orderSource: OrderSource.Amazon.value) { response, error in
            self.sendServicesDownCallback(error: error)
        }
    }
    
    /*
     * add user account details in DB
     */
    private func addUserAccountInDB() {
        let account = self.account as! UserAccount
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: AccountState.Connected.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    /*
     * get progress value in the range 0 to 1 from step number
     **/
    private func publishProgrssFor(step : Step) {
        var logEventAttributes:[String:String] = [:]
        let progressValue = Float(step.rawValue) / AppConstants.numberOfSteps
        var stepMessage: String
        
        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
        case .generateReport:
            stepMessage = Utils.getString(key: Strings.Step2)
        case .downloadReport:
            stepMessage = Utils.getString(key: Strings.Step3)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.account.userID,
                                  EventConstant.PanelistID: self.account.panelistID,
                                  EventConstant.ScrappingMode: scrapingMode.rawValue,
                                  EventConstant.ScrappingStep: Step.downloadReport.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepDownloadReport, eventAttributes: logEventAttributes)

        case .parseReport:
            stepMessage = Utils.getString(key: Strings.Step4)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.account.userID,
                                  EventConstant.PanelistID: self.account.panelistID,
                                  EventConstant.ScrappingMode: scrapingMode.rawValue,
                                  EventConstant.ScrappingStep: Step.parseReport.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepParseReport, eventAttributes: logEventAttributes)

        case .uploadReport:
            stepMessage = Utils.getString(key: Strings.Step5)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.account.userID,
                                  EventConstant.PanelistID: self.account.panelistID,
                                  EventConstant.ScrappingMode: scrapingMode.rawValue,
                                  EventConstant.ScrappingStep: Step.uploadReport.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepUploadReport, eventAttributes: logEventAttributes)

        case .complete:
            stepMessage = Utils.getString(key: Strings.Step6)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.account.userID,
                                  EventConstant.PanelistID: self.account.panelistID,
                                  EventConstant.ScrappingMode: scrapingMode.rawValue,
                                  EventConstant.ScrappingStep: Step.complete.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepComplete, eventAttributes: logEventAttributes)
        }
        
        self.scraperListener.updateProgressValue(progressValue: progressValue)
        self.scraperListener.updateStepMessage(stepMessage: stepMessage)
        
        if step == .complete {
            self.webView.navigationDelegate = nil
            self.scraperListener.onCompletion(isComplete: true)
        }
    }
    
    private func didFinishWith(error: ASLException) {
        do {
            try CoreDataManager.shared.updateUserAccount(userId: self.param!.account.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.param!.account.panelistID, orderSource: self.param!.account.source.rawValue)
        } catch {
            print("updateAccountWithExceptionState")
        }
        _ = AmazonService.updateStatus(platformId: self.param!.account.userID, status: AccountState.ConnectedButException.rawValue, message: AppConstants.msgAuthError, orderStatus: OrderStatus.Failed.rawValue,orderSource: OrderSource.Amazon.value) { response, error in
            self.sendServicesDownCallback(error: error)
        }
        self.param!.listener.onHtmlScrappingFailure(error: error)
    }
    private func logEvents(message: String, section: String, status: String, type: String, scrapingContext: String) {
        let eventLogs = EventLogs(panelistId: self.account!.panelistID, platformId: self.account!.userID, section: section, type: type , status: status, message: message, fromDate: self.dateRange!.fromDate!, toDate: self.dateRange!.toDate!, scrapingType: ScrappingType.report.rawValue, scrapingContext: scrapingContext,url:webView.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.account!.source.value) { response, error in
            self.sendServicesDownCallback(error: error)
        }
    }
    func sendServicesDownCallback(error: ASLException?) {
        if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
            if scrapingMode == .Foreground {
                let aslException = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                scraperListener.onServicesDown(error: aslException)
            }
        }
    }
    private func getScript(orderSource: OrderSource, scriptKey: String, completionHandler: @escaping(String) -> Void) {
            BSScriptFileManager.shared.getAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
                if !script.isEmpty {
                    completionHandler(script)
                } else {
                    BSScriptFileManager.shared.getNewAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
                        print("!!!! Script found",script)
                        completionHandler(script)
                    }
                }
            }
    }
    
    private func checkCurrentReportPage(key: String) {
        self.getScript(orderSource: .Amazon, scriptKey: key) { script in
            if !script.isEmpty {
                self.webView.evaluateJavaScript(script) { response, error in
                    if let response = response as? String {
                        if response == "true" {
                            //self.injectDownloadReportJS()
                        } else {
                            self.evaluateJS(jsType: .dateRange, javascript: self.getOldestPossibleYear())
                        }
                    }
                }
            } else {
                if self.scrapingMode == .Background {
                    let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "checkCurrentReportPage for amazon", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: ScrappingType.html)
                    self.bsScrapper!.onAuthenticationFailure(error: errorMessage, orderSource: self.account.source)
                } else {
                    self.logEvents(message: Strings.ErrorScriptNotFound + "checkCurrentReportPage for amazon", section: SectionType.connection.rawValue, status: EventState.fail.rawValue, type: FailureTypes.other.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                    let error = ASLException(errorMessage: Strings.ErrorScriptNotFound + "checkCurrentReportPage for amazon", errorType: .authError)
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
            }
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
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                              EventConstant.ScrappingType: ScrappingType.report.rawValue,
                              EventConstant.EventName: EventType.DidFailPageNavigation]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,"An error occurred during the early navigation process", error.localizedDescription)
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                              EventConstant.ScrappingType: ScrappingType.report.rawValue,
                              EventConstant.EventName: EventType.DidFailProvisionalNavigation]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print(AppConstants.tag, "webViewWebContentProcessDidTerminate()")
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingMode: self.scrapingMode.rawValue,
                              EventConstant.ScrappingType: ScrappingType.report.rawValue,
                              EventConstant.EventName: EventType.WebContentProcessDidTerminate]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.WebContentProcessDidTerminate, eventAttributes: logEventAttributes)
    }
}
