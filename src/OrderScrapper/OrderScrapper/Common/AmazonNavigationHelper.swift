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
    private var backgroundScrapper: BSScrapper!
    
    private lazy var CSVScrapper: BSCSVScrapper = {
        return BSCSVScrapper(webview: self.webView, scrapingMode: .Foreground, scraperListener: self.scraperListener)
    }()
    
    required init(_ viewModel: WebViewModel, webView: WKWebView, scraperListener: ScraperProgressListener,
                  timerHandler: TimerHandler) {
        self.viewModel = viewModel
        self.authenticator = AmazonAuthenticator(viewModel)
        self.webView = webView
        self.scraperListener = scraperListener
        self.timerHandler = timerHandler
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    // MARK:- NavigationHelper Methods
    func navigateWith(url: URL?) {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if (urlString.contains(AmazonURL.signIn)) {
            if self.authenticator.isUserAuthenticated() {
                self.viewModel.authenticationComplete.send(true)
                self.authenticator.resetAuthenticatedFlag()
            } else {
                self.authenticator.authenticate()
                self.currentStep = .authentication
                publishProgrssFor(step: .authentication)
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
                                      EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: eventType, eventAttributes: logAuthEventAttributes)
            let eventLogs = EventLogs(panelistId: self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.connection.rawValue, type: FailureTypes.other.rawValue, status: EventState.success.rawValue, message: "Authentication challenge", fromDate: nil, toDate: nil, scrappingType: nil)
            logEvents(logEvents: eventLogs)
        } else if (urlString.contains(AmazonURL.generateReport)) {
            let userAccountState = self.viewModel.userAccount.accountState
            if userAccountState == AccountState.NeverConnected {
                let userId = self.viewModel.userAccount.userID
                _ = AmazonService.registerConnection(amazonId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue) { response, error in
                    if let response = response  {
                        //On authentication add user account details to DB
                        self.addUserAccountInDB()
                        self.viewModel.userAccount.isFirstConnectedAccount = response.firstaccount
                        self.getDateRange()
                        self.currentStep = .generateReport
                        self.publishProgrssFor(step: .generateReport)
                    } else {
                        self.viewModel.authError.send((isError: true, errorMsg: AppConstants.userAccountConnected))
                        if let error = error {
                            SentrySDK.capture(error: error)
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
        } else if (urlString.contains(AmazonURL.resetPassword)) {
            let userAccountState = self.viewModel.userAccount.accountState
            if userAccountState != AccountState.NeverConnected {
                do {
                    try CoreDataManager.shared.updateUserAccount(userId: self.viewModel.userAccount.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.viewModel.userAccount.panelistID)
                } catch {
                    print("updateAccountWithExceptionState")
                }
            }
            self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgResetPassword))
            self.timerHandler.stopTimer()
        } else if (urlString.contains(AmazonURL.reportSuccess)) {
            //No handling required
        } else {
            print(AppConstants.tag, "unknown URL", urlString)
            //Log event for getting other url
            var logOtherUrlEventAttributes:[String:String] = [:]
            logOtherUrlEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.Status: EventStatus.Success,
                                          EventConstant.URL: urlString]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectOtherURL, eventAttributes: logOtherUrlEventAttributes)
            
            let eventLogs = EventLogs(panelistId: self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.connection.rawValue, type: FailureTypes.other.rawValue, status: EventState.fail.rawValue, message: "unknow URL", fromDate: nil, toDate: nil, scrappingType: nil)
            logEvents(logEvents: eventLogs)
            guard let currentStep = self.currentStep else {
                return
            }
            
            if currentStep == .authentication {
                self.viewModel.showWebView.send(true)
            } else {
                self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgUnknownURL))
            }
            self.timerHandler.stopTimer()
        }
        
        //Timer handling for each step
        switch currentStep {
        case .authentication:
            if (urlString.contains(AmazonURL.authApproval) &&
                    urlString.contains(AmazonURL.twoFactorAuth)) {
                self.timerHandler.stopTimer()
            } else {
                self.timerHandler.startTimer(action: Actions.DoingAuthentication)
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
                    if response.scrappingType == ScrappingType.report.rawValue {
                        self.scrapeReport(response: response)
                    } else {
                        self.timerHandler.stopTimer()
                        self.scrapeHtml()
                    }
                } else {
                    self.updateAccountStatusToConnected(orderStatus: OrderStatus.None.rawValue)
                    self.viewModel.disableScrapping.send(true)
                }
                //Logging event for successful date range API call
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            } else {
                self.updateOrderStatusFor(error: AppConstants.msgDateRangeAPIFailed, accountStatus: AccountState.Connected.rawValue)
                self.viewModel.webviewError.send(true)
                //Log event for failure of date range API call
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIDateRange, eventAttributes: logEventAttributes)
            }
        }
    }
    
    private func scrapeReport(response: DateRange) {
        let account = self.viewModel.userAccount
        self.CSVScrapper.scrapeOrders(response: response, account: account!, timerHandler: self.timerHandler, param: nil)
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
                if completed {
                    self.scraperListener.updateSuccessType(successType: successType!)
                    self.scraperListener.onCompletion(isComplete: true)
                    UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
                } else {
                    self.scraperListener.updateSuccessType(successType: .failureButAccountConnected)
                    self.scraperListener.onCompletion(isComplete: true)
                }
                
                self.backgroundScrapper.scraperListener = nil
                self.backgroundScrapper = nil
            }
        }
        self.backgroundScrapper.scraperListener = self.scraperListener
        self.backgroundScrapper.scrappingMode = .Foreground
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
    
    private func logEvents(logEvents: EventLogs) {
        _ = AmazonService.logEvents(eventLogs: logEvents) { respose, error in
            
        }
    }
}
