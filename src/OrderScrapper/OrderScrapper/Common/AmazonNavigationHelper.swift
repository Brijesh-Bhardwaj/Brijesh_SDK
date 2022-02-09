//
//  AmazonNavigationHelper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine
import Sentry
import WebKit

struct AmazonURL {
    static let signIn           =   "ap/signin"
    static let authApproval     =   "ap/cvf/approval"
    static let twoFactorAuth    =   "ap/mfa"
    static let downloadReport   =   "download-report"
    static let reportID         =   "reportId"
    static let generateReport   =   "gp/b2b/reports/"
    static let resetPassword    =   "ap/forgotpassword/reverification"
    static let reportSuccess    =   "gp/b2b/reports?"
    static let orderHistory     =   "/gp/your-account/order-history"
}

public enum Step: Int16 {
    case authentication = 1,
         generateReport = 2,
         downloadReport = 3,
         parseReport = 4,
         uploadReport = 5,
         complete = 6
    
    var value: String {
        return String(describing: self)
    }
}

class AmazonNavigationHelper: NavigationHelper {
    @ObservedObject var viewModel: WebViewModel
    private var currentStep: Step!
    private var timer: Timer?
    var jsResultSubscriber: AnyCancellable? = nil
    let authenticator: Authenticator
    var webView: WKWebView
    let scraperListener: ScraperProgressListener
    let timerHandler: TimerHandler!
    var backgroundScrapper: BSScrapper!
    var isGenerateReport: Bool = false
    var fetchRequestSource: FetchRequestSource?

    private lazy var CSVScrapper: BSCSVScrapper = {
        return BSCSVScrapper(webview: self.webView, scrapingMode: .Foreground, scraperListener: self.scraperListener)
    }()
    
    required init(_ viewModel: WebViewModel, webView: WKWebView, scraperListener: ScraperProgressListener,
                  timerHandler: TimerHandler, fetchRequestSource: FetchRequestSource?) {
        self.viewModel = viewModel
        self.authenticator = AmazonAuthenticator(viewModel, scraperListener)
        self.webView = webView
        self.scraperListener = scraperListener
        self.timerHandler = timerHandler
        self.fetchRequestSource = fetchRequestSource
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    // MARK:- NavigationHelper Methods
    func navigateWith(url: URL?) {

        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.ScrappingType: ScrappingType.report.rawValue,
                              EventConstant.URL: urlString,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UrlLoadedReportScrapping, eventAttributes: logEventAttributes)

        if (urlString.contains(AmazonURL.signIn)) {
            if self.authenticator.isUserAuthenticated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                    guard let self = self else {return}
                    self.authenticator.resetAuthenticatedFlag()
                    self.viewModel.authenticationComplete.send(true)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                    guard let self = self else {return}
                    self.authenticator.authenticate()
                    self.currentStep = .authentication
                    self.publishProgrssFor(step: .authentication)
                }
            }
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
            logAuthEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                      EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                      EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: eventType, eventAttributes: logAuthEventAttributes)
            
            let eventLogs = EventLogs(panelistId: self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.connection.rawValue, type: FailureTypes.other.rawValue, status: EventState.success.rawValue, message: "Authentication challenge", fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
            logEvents(logEvents: eventLogs)
        } else if (urlString.contains(AmazonURL.generateReport)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else {return}
                
                if self.isGenerateReport {
                    return
                } else {
                    self.isGenerateReport = true
                    
                    let userAccountState = self.viewModel.userAccount.accountState
                    if userAccountState == AccountState.NeverConnected {
                        let userId = self.viewModel.userAccount.userID
                        _ = AmazonService.registerConnection(platformId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue, orderSource: OrderSource.Amazon.value) { response, error in
                            var logEventAttributes:[String:String] = [:]
                            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                                      EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                                      EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                                      EventConstant.ScrappingType: ScrappingType.report.rawValue]
                            if let response = response  {
                                //On authentication add user account details to DB
                                self.addUserAccountInDB()
                                self.viewModel.userAccount.isFirstConnectedAccount = response.firstaccount
                                self.getDateRange()
                                self.currentStep = .generateReport
                                self.publishProgrssFor(step: .generateReport)
                                
                                //TODO Add response in attributes
                                logEventAttributes[EventConstant.Status] = EventStatus.Success
                                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIRegisterUser, eventAttributes: logEventAttributes)
                            } else {
                                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                                    self.sendServicesDownCallback()
                                } else {
                                    self.viewModel.authError.send((isError: true, errorMsg: AppConstants.userAccountConnected))
                                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                                    if let error = error {
                                        logEventAttributes[EventConstant.EventName] = EventType.UserRegistrationAPIFailed
                                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                                    } else {
                                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UserRegistrationAPIFailed, eventAttributes: logEventAttributes)
                                    }
                                }
                            }
                        }
                    } else {
                        //On authentication add user account details to DB
                        self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                        self.addUserAccountInDB()
                        self.getDateRange()
                        self.currentStep = .generateReport
                        self.publishProgrssFor(step: .generateReport)
                    }
                }
            }
        } else if (urlString.contains(AmazonURL.resetPassword)) {
            let userAccountState = self.viewModel.userAccount.accountState
            if userAccountState != AccountState.NeverConnected {
                do {
                    try CoreDataManager.shared.updateUserAccount(userId: self.viewModel.userAccount.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.viewModel.userAccount.panelistID, orderSource: self.viewModel.userAccount.source.rawValue)
                } catch {
                    print("updateAccountWithExceptionState")
                }
            }
            self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgResetPassword))
            self.timerHandler?.stopTimer()
        } else if (urlString.contains(AmazonURL.reportSuccess)) {
            //No handling required
        } else {
            print(AppConstants.tag, "unknown URL", urlString)
            //Log event for getting other url
            var logOtherUrlEventAttributes:[String:String] = [:]
            logOtherUrlEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                          EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                          EventConstant.Status: EventStatus.Success,
                                          EventConstant.URL: urlString]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepOtherURLLoaded, eventAttributes: logOtherUrlEventAttributes)
            
            let eventLogs = EventLogs(panelistId: self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.connection.rawValue, type: FailureTypes.other.rawValue, status: EventState.fail.rawValue, message: "unknow URL", fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
            logEvents(logEvents: eventLogs)
            guard let currentStep = self.currentStep else {
                return
            }
            
            if currentStep == .authentication {
                self.viewModel.showWebView.send(true)
            } else {
                self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgUnknownURL))
            }
            self.timerHandler?.stopTimer()
        }
        
        //Timer handling for each step
        switch currentStep {
        case .authentication:
            if (urlString.contains(AmazonURL.authApproval) &&
                    urlString.contains(AmazonURL.twoFactorAuth)) {
                self.timerHandler?.stopTimer()
            } else {
                self.timerHandler?.startTimer(action: Actions.DoingAuthentication)
            }
        case .downloadReport:
            print("### Do nothing")
        //self.timerHandler.startTimer(viewModel: self.viewModel)
        case .generateReport, .parseReport, .uploadReport, .complete, .none:
            print("### Do nothing")
        }
    }
    
    func shouldShowWebViewFor(url: URL?) -> Bool {
        guard let url = url else { return false }
        
        let urlString = url.absoluteString
        
        let knownURLs = urlString.contains(AmazonURL.signIn)
            || (urlString.contains(AmazonURL.downloadReport) && urlString.contains(AmazonURL.reportID))
            || urlString.contains(AmazonURL.generateReport)
            || urlString.contains(AmazonURL.resetPassword)
            || urlString.contains(AmazonURL.reportSuccess)
        
        // Always hide for known URLs
        if knownURLs {
            return false
        }
        
        if urlString.contains(AmazonURL.authApproval)
            || urlString.contains(AmazonURL.twoFactorAuth) {
            return true
        }
        
        guard let currentStep = self.currentStep else { return false }
        
        // For unknown URL, hide if current step is not authentication step
        return (currentStep == .authentication)
    }
    
    /*
     * get progress value in the range 0 to 1 from step number
     **/
    private func publishProgrssFor(step : Step) {
        var logEventAttributes:[String:String] = [:]
        let progressValue = Float(step.rawValue) / AppConstants.numberOfSteps
        var progressMessage: String?
        var headerMessage: String?
        var stepMessage: String
        
        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
            headerMessage = Utils.getString(key: Strings.HeadingConnectAmazonAccount)
            progressMessage = Utils.getString(key: Strings.HeadingConnectingAmazonAccount)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                  EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                  EventConstant.ScrappingStep: Step.authentication.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepAuthentication, eventAttributes: logEventAttributes)
        case .generateReport:
            stepMessage = Utils.getString(key: Strings.Step2)
            headerMessage = Utils.getString(key: Strings.HeadingFetchingReceipts)
            progressMessage = Utils.getString(key: Strings.HeadingFetchingYourReceipts)
            
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                  EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                  EventConstant.ScrappingStep: Step.generateReport.value,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.StepGenerateReport, eventAttributes: logEventAttributes)
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
        var forceScrape = false
        if let source = self.fetchRequestSource, source == .manual {
            //For manual scraping send forcescrape as true to date range API
            forceScrape = true
        }
        var logEventAttributes:[String:String] = [:]
        _ = AmazonService.getDateRange(platformId: self.viewModel.userAccount.userID,
                                       orderSource: OrderSource.Amazon.value, forceScrape: forceScrape) { response, error in
            if let response = response {
                if response.enableScraping {
                    
                    //Clear order details from DB while doing foreground scrapping
//                    let account = self.viewModel.userAccount as! UserAccountMO
//                    CoreDataManager.shared.deleteOrderDetails(userID: account.userID, panelistID: account.panelistID, orderSource: account.source.value)
                    
                    if response.scrappingType == ScrappingType.report.rawValue {
                        if self.fetchRequestSource == .manual {
                            self.getTimerValue(type: .report) { timerValue in
                                self.timerHandler.startTimer(action: Actions.ForegroundCSVScrapping, timerInterval: TimeInterval(timerValue))
                                self.scrapeReport(response: response)
                            }
                       
                        } else {
                            self.scrapeReport(response: response)
                        }
                    } else {
                        self.timerHandler?.stopTimer()
                        if self.fetchRequestSource == .manual {
                            self.getTimerValue(type: .html) { timerValue in
                                self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: TimeInterval(timerValue))
                                self.scrapeHtml()
                            }
                        } else {
                            self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                            self.scrapeHtml()
                        }
                    }
                } else {
                    self.updateAccountStatusToConnected(orderStatus: OrderStatus.None.rawValue)
                    self.viewModel.disableScrapping.send(true)
                }
                //Logging event for successful date range API call
                var json: String
                do {
                    let jsonData = try JSONEncoder().encode(response)
                    json = String(data: jsonData, encoding: .utf8)!
                } catch {
                    json = AppConstants.ErrorInJsonEncoding
                }
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                      EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                      EventConstant.Data: json,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            } else {
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback()
                } else {
                    self.updateOrderStatusFor(error: AppConstants.msgDateRangeAPIFailed, accountStatus: AccountState.Connected.rawValue)
                    self.viewModel.webviewError.send(true)
                    //Log event for failure of date range API call
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                          EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.EventName: EventType.ExceptionWhileDateRangeAPI,
                                          EventConstant.Status: EventStatus.Failure]
                    if let error = error {
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.ExceptionWhileDateRangeAPI, eventAttributes: logEventAttributes)
                    }
                }
            }
        }
    }
    
    private func scrapeReport(response: DateRange) {
        if let account = self.viewModel.userAccount {
            self.CSVScrapper.scrapeOrders(response: response, account: account, timerHandler: self.timerHandler, param: nil)
        }
    }
    
    private func scrapeHtml() {
        if self.backgroundScrapper != nil {
            self.backgroundScrapper.scraperListener = nil
            self.backgroundScrapper = nil
        }
        
        //Start html scrapping in the foreground
        let scriptMessageHandler = BSScriptMessageHandler()
        let contentController = WKUserContentController()
        contentController.add(scriptMessageHandler, name: "iOS")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        let frame = CGRect(x: 0, y: 0, width: 250, height: 400)
        let webClient = BSWebClient(frame: frame, configuration: config, scriptMessageHandler: scriptMessageHandler)
        let account = self.viewModel.userAccount!
        
        self.backgroundScrapper = AmazonScrapper(webClient: webClient) { [weak self] result, error in
            guard let self = self else {return}
            let (completed, successType) = result
            DispatchQueue.main.async {
                self.timerHandler?.stopTimer()
                if completed {
                    if let successType = successType {
                        self.scraperListener.updateSuccessType(successType: successType)
                    }
                    self.scraperListener.onCompletion(isComplete: true)
                    UserDefaults.standard.setValue(0, forKey: Strings.AmazonOnNumberOfCaptchaRetry)
                } else {
                    self.scraperListener.updateSuccessType(successType: .failureButAccountConnected)
                    self.scraperListener.onCompletion(isComplete: false)
                }
                
                self.backgroundScrapper?.scraperListener = nil
                self.backgroundScrapper = nil
            }
        }
        self.backgroundScrapper.scraperListener = self.scraperListener
        self.backgroundScrapper.scrappingMode = .Foreground
        if let fetchRequestSource = fetchRequestSource {
            self.backgroundScrapper.fetchRequestSource = fetchRequestSource
        }
        self.backgroundScrapper.startScrapping(account: account)
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
        _ = AmazonService.updateStatus(platformId: amazonId,
                                       status: accountStatus,
                                       message: error,
                                       orderStatus: OrderStatus.Failed.rawValue, orderSource:  OrderSource.Amazon.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    
    private func updateAccountStatusToConnected(orderStatus: String) {
        let amazonId = self.viewModel.userAccount.userID
        _ = AmazonService.updateStatus(platformId: amazonId,
                                       status: AccountState.Connected.rawValue,
                                       message: AppConstants.msgConnected,
                                       orderStatus: orderStatus, orderSource:  OrderSource.Amazon.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    
    private func logEvents(logEvents: EventLogs) {
        _ = AmazonService.logEvents(eventLogs: logEvents, orderSource: self.viewModel.userAccount.source.value) { respose, error in
             if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    
    private func sendServicesDownCallback() {
        let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
        self.scraperListener.onServicesDown(error: error)
    }
    
    private func getTimerValue(type: ScrappingType, completion: @escaping (Double) -> Void) {
        ConfigManager.shared.getConfigurations(orderSource: self.viewModel.userAccount.source) { (configurations, error) in
            var timerValue: Double = 0
            if let configuration = configurations {
                if type == .report {
                    timerValue = configuration.manualScrapeReportTimeout ?? AppConstants.timeoutManualScrapeCSV
                } else {
                    timerValue = configuration.manualScrapeTimeout ?? AppConstants.timeoutManualScrape
                }
            } else {
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    
                    logEventAttributes = [EventConstant.OrderSource: self.viewModel.userAccount.userID,
                                          EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                // In case of configurations not found
                if type == .report {
                    timerValue = AppConstants.timeoutManualScrapeCSV
                } else {
                    timerValue = AppConstants.timeoutManualScrape
                }
            }
            completion(timerValue)
        }
    }
}
