//
//  OnlineScrapingPresenter.swift
//  OrderScrapper
//
//  Created by Avinash Mohanta on 23/02/22.
//

import Foundation
import UIKit

enum SubviewButton {
    case back, retry, stop, continueOperation, doLater, ok, done, scrapeAagain
}

protocol OnlineScrapingPresenter {
    func attachView(view: OnlineScrapingView)
    
    func detachView()
    
    func beginScraping()
    
    func didClickButton(button: SubviewButton)
}

final class OnlineScrapingPresenterImpl: NSObject, TimerCallbacks {
    private var view: OnlineScrapingView?
    
    private var networkMonitor: NetworkMonitor?
    private var accounts: [Account] = []
    private var backgroundScrapper: BSScrapper!
    private var currentScrapingIndex: Int = 0
    private var isUserEligible = LibContext.shared.isIncetiveFlag
    private var fetchRequestSource: FetchRequestSource!
    private var isScraping: Bool = false
    private var getScrapeSessionTimer: String? = nil
    
    lazy var timerHandler: TimerHandler = {
        return TimerHandler(timerCallback: self)
    }()
    
    lazy var scrapingStatusMap: [Int : [OrderSource: String]] = {
        return [Int : [OrderSource: String]]()
    }()
    
    required init(accounts: [Account]) {
        super.init()
        //self.accounts.removeAll()
        self.accounts = accounts
        self.networkMonitor = NetworkMonitor(listener: self)
        self.isScraping = false
    }
    
    deinit {
        self.networkMonitor?.removeListener()
        self.networkMonitor = nil
    }
    
    
    func onTimerTriggered(action: String) {
        if action == Actions.ForegroundHtmlScrapping {
            print("!!!! onTimerTriggered called")
            self.view?.displaySubview(subview: .timeout, params: SubviewParams(header: nil, title: nil, message: LibContext.shared.onlineScrapingTimeoutMessage, continueButton: false, doItLater: false, IncetiveMessage: "", okButton: true, successImage: getStatusImage(value: true), doneButton: true, retryButton: true))
        }
    }
    
    func getTimerValue(account: Account, completion: @escaping (Double) -> Void) {
        ConfigManager.shared.getConfigurations(orderSource: account.source) { (configurations, error) in
            var timerValue: Double = 0
            if let configuration = configurations {
                timerValue = configuration.manualScrapeTimeout ?? AppConstants.timeoutManualScrape
            } else {
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    
                    logEventAttributes = [EventConstant.OrderSource: account.source.value,
                                          EventConstant.PanelistID: account.panelistID,
                                          EventConstant.OrderSourceID: account.userID,
                                          EventConstant.EventName: EventType.ExceptionWhileGettingConfiguration,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                // Configurations not found then return default value
                timerValue = 1800
            }
            completion(timerValue)
        }
    }
    
    //MARK: - Private Methods
    
    private func getScrapingClient(account: Account) -> BSScrapper {
        switch account.source {
        case .Amazon:
            self.backgroundScrapper = AmazonScrapper(webClient: self.getWebClient()) { [weak self] result, error in
                guard let self = self else {return}
                self.scrapperCallback(result: result, error: error, account: account)
            }
            return self.backgroundScrapper
        case .Instacart:
            self.backgroundScrapper = InstacartScrapper(webClient: self.getWebClient()) { [weak self] result, error in
                guard let self = self else {return}
                self.scrapperCallback(result: result, error: error, account: account)
            }
            return self.backgroundScrapper
        case .Kroger:
            self.backgroundScrapper = KrogerScrapper(webClient: self.getWebClient()) { [weak self] result, error in
                guard let self = self else {return}
                self.scrapperCallback(result: result, error: error, account: account)
            }
            return self.backgroundScrapper
        case .Walmart:
            self.backgroundScrapper = WalmartScrapper(webClient: self.getWebClient()) { [weak self] result, error in
                guard let self = self else {return}
                self.scrapperCallback(result: result, error: error, account: account)
            }
            return self.backgroundScrapper
        }
    }
    
    private func getAccountByScrapingIndex(scrapingIndex: Int) -> Account? {
        if scrapingIndex >= accounts.count {
            return nil
        }
        return accounts[scrapingIndex]
    }
    
    private func updateOnlineAccountState(account: Account, status: String) {
        self.scrapingStatusMap[self.currentScrapingIndex] = [account.source: status]
        self.currentScrapingIndex += 1
    }
    
    private func getWebClient() -> BSWebClient {
        return (self.view?.getWebClient())!
    }
    
    private func checkFailedAccountStatus() {
        if let _ = scrapingStatusMap[currentScrapingIndex] {
        }
        
    }
    
    private func getFailureMessage() -> String {
        return LibContext.shared.onlineScrapingFailedMessage
    }
    
    private func getStatusImage(value: Bool) -> UIImage? {
        if value {
            return Utils.getImage(named: IconNames.SuccessScreen)
        }  else {
            return Utils.getImage(named: IconNames.FailureScreen)
        }
    }
    
    private func scrapeAccount() {
        if let account = self.getAccountByScrapingIndex(scrapingIndex: currentScrapingIndex) {
            if checkFailedAccountStatus(orderSource: account.source,scrapingIndex:currentScrapingIndex) {
                self.setHeader(isUploadingPreviousOrders: false, orderSource: account.source.value)
                self.scrapingStatusMap[self.currentScrapingIndex] = [account.source: OnlineAccountState.InProgress.rawValue]
                self.backgroundScrapper =  self.getScrapingClient(account: account)
                backgroundScrapper.scraperListener = self
                if isUserEligible {
                    backgroundScrapper.fetchRequestSource = .online
                    self.fetchRequestSource = .online
                } else {
                    backgroundScrapper.fetchRequestSource = .manual
                    self.fetchRequestSource = .manual
                }
                backgroundScrapper.scrappingMode = .Foreground
                self.updateProgressValue(progressValue: 10)
                self.getTimerValue(account: account) { timerValue in
                    print("!!!! timer value",timerValue)
                    self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: timerValue)
                    self.backgroundScrapper.startScrapping(account: account)
                }
            } else {
                currentScrapingIndex += 1
                scrapeAccount()
            }
            
        } else {
            self.onCompletion(isComplete: true)
        }
    }
    
    private func setupAccountsForScraping() {
        self.scrapingStatusMap.removeAll()
        var scrapingIndex: Int = 0
        for account in accounts {
            self.scrapingStatusMap[scrapingIndex] = [account.source : OnlineAccountState.NotStarted.rawValue]
            scrapingIndex += 1
            print("!!!! OnlineScrapingPresenterImpl account",account.source)
        }
    }
    
    private func setHeader(isUploadingPreviousOrders: Bool, orderSource: String) {
        if isUploadingPreviousOrders {
            self.view?.setHeaderTitle(title: Strings.OnlineHeaderPendingFetchingOrders)
        } else {
            self.view?.setHeaderTitle(title: String.init(format: Strings.OnlineFetchingOrders, orderSource))
        }
    }
    
    private func scrapperCallback(result: (Bool, OrderFetchSuccessType?), error: ASLException?, account: Account) {
        let (completed, successType) = result
        self.timerHandler.stopTimer()
        DispatchQueue.main.async {
            if completed {
                print("!!!! ",successType!)
                let numberOfCapchaRetry = Utils.getKeyForNumberOfCaptchaRetry(orderSorce: account.source)
                UserDefaults.standard.setValue(0, forKey: numberOfCapchaRetry)
                self.updateProgressValue(progressValue: 100)
                self.updateOnlineAccountState(account: account, status: OnlineAccountState.Completed.rawValue)
            } else {
                self.updateOnlineAccountState(account: account, status: OnlineAccountState.Failed.rawValue)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.scrapeAccount()
            }
        }
        self.backgroundScrapper = nil
    }
    
    private func checkFailedAccountStatus(orderSource:OrderSource,scrapingIndex: Int) -> Bool {
        if let accountData = scrapingStatusMap[scrapingIndex] {
            let status = accountData[orderSource]
            if(status != "Completed"){
                return true
            }
        }
        return false
    }
    
    private func getSuccessMessage() -> String {
        
        if !LibContext.shared.hasNoOrdersInLastWeek() {
            if self.fetchRequestSource == .manual {
                return LibContext.shared.noNewManualOrders
            } else {
                return LibContext.shared.noOrdersInWeekMessage
            }
        }
        else if self.fetchRequestSource == .manual {
            return LibContext.shared.manualScrapeSuccess
        } else {
            return LibContext.shared.onlineScrapingSuccessMessage
        }
    }
    
    private func getSuccessMessageNote() -> String {
        var successNote = ""
        let showSuccessNote = self.fetchRequestSource == .online && LibContext.shared.hasNoOrdersInLastWeek()
        if showSuccessNote {
            //If online and has orders case
            successNote = LibContext.shared.onlineScrapingSuccessNote
        }
        else if !LibContext.shared.hasNoOrdersInLastWeek() {
            //Zero orders case
            if self.fetchRequestSource == .manual {
                successNote =  LibContext.shared.noNewManualOrdersNote
            } else {
                successNote = LibContext.shared.onlineZeroOrdersNote
            }
        }
        else {
            //Manual scrapping case
            successNote = LibContext.shared.manualScrapeNote
        }
        return successNote
    }
    
    private func hasPreviousWeekOrders() -> Bool {
        var isPreviosWeekOrders: Bool = false
        if !LibContext.shared.hasNoOrdersInLastWeek()  {
                isPreviosWeekOrders = true
        }
        return isPreviosWeekOrders
    }
    
    private func getSuccessTitle() -> String {
        var successTitle = "Congratulations!"
        
        let showSuccessTitle = (self.fetchRequestSource == .online || self.fetchRequestSource == .manual) && !LibContext.shared.hasNoOrdersInLastWeek()
        if showSuccessTitle {
            if self.fetchRequestSource == .manual {
                successTitle = "No New Orders"
            } else {
                successTitle = "0 Orders"
            }

        }
        return successTitle
    }
    
    private func getButtonTitle() -> String {
        var successTitle = "Great!"
        let showSuccessTitle = (self.fetchRequestSource == .online || self.fetchRequestSource == .manual) && !LibContext.shared.hasNoOrdersInLastWeek()
        if showSuccessTitle {
            successTitle = "Complete"
        }
        return successTitle
    }
    
    private func getSessionStartTime() -> String? {
        if fetchRequestSource == .online {
            return nil
        }
        
        return getScrapeSessionTimer ?? nil
    }
}

extension OnlineScrapingPresenterImpl: OnlineScrapingPresenter {
    func didClickButton(button: SubviewButton) {
        // based on some logic
        switch button {
        case .back:
            self.view?.goBackToPreviousScreen()
        case .retry:
            guard let networkMonitor = self.networkMonitor else { return }
            
            if networkMonitor.hasNetwork() {
                self.view?.displaySubview(subview: .progress, params: nil)
                self.beginScraping()
            }
        case .stop:
            self.view?.goBackToPreviousScreen()
        case .continueOperation:
            if let account = self.getAccountByScrapingIndex(scrapingIndex: currentScrapingIndex) {
                self.view?.displaySubview(subview: .progress, params: nil)
                self.getTimerValue(account: account) { timerValue in
                    self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: TimeInterval(timerValue))
                }
            }
            
        case .doLater:
            if backgroundScrapper != nil {
                self.backgroundScrapper.stopScrapping()
                self.backgroundScrapper.scraperListener = nil
                self.backgroundScrapper = nil
            }
            if let account = self.getAccountByScrapingIndex(scrapingIndex: currentScrapingIndex) {
                self.updateOnlineAccountState(account: account, status: OnlineAccountState.Failed.rawValue)
            }
            if currentScrapingIndex <= accounts.count {
                self.view?.displaySubview(subview: .progress, params: nil)
            }
            self.scrapeAccount()
        case .ok:
            self.view?.goBackToPreviousScreen()
        case .done:
            self.view?.goBackToPreviousScreen()
        case .scrapeAagain:
            print("!!!1 scrapeAagain button called")
            self.currentScrapingIndex = 0
            self.view?.displaySubview(subview: .progress, params: nil)
            self.scrapeAccount()
            
        }
    }
    
    func attachView(view: OnlineScrapingView) {
        self.view = view
        
    }
    
    func detachView() {
        self.view = nil
    }
    
    func beginScraping() {
        //TODO : - Error handling required
        if !isScraping {
            self.setupAccountsForScraping()
            getScrapeSessionTimer = DateUtils.getSessionTimer(getSessionTimeForOnline: .online)
            self.scrapeAccount()
            self.isScraping = true
        }
        
    }
}

extension OnlineScrapingPresenterImpl: NetworkChangeListener {
    func onNetworkChange(status: NetworkStatus) {
        switch(status) {
        case .connected:
            self.view?.displaySubview(subview: .progress, params: nil)
            self.scrapeAccount()
        case .disconnected:
            self.view?.displaySubview(subview: .networkError, params: nil)
        }
    }
}

extension OnlineScrapingPresenterImpl: ScraperProgressListener {
    func onWebviewError(isError: Bool) {
        //
    }
    
    func onCompletion(isComplete: Bool) {
        var accountStatus: String = OnlineAccountState.Completed.rawValue
        for data in scrapingStatusMap {
            let status = data.value.values
            if status.contains(OnlineAccountState.Failed.rawValue) {
                accountStatus = OnlineAccountState.Failed.rawValue
                break
            }
        }
        
        if accountStatus == OnlineAccountState.Completed.rawValue {
            Utils.isPreviousWeeksOrders(sessionTimer: getSessionStartTime()) { response in
                    self.view?.displaySubview(subview: .onlineSuccess, params: SubviewParams(header: nil, title: nil, message: self.getSuccessMessage(), continueButton: true, doItLater: true, IncetiveMessage: self.getSuccessMessageNote(), okButton: false, successImage: self.getStatusImage(value: true), doneButton: true, retryButton: true, onlineSuccesMessage: self.getSuccessTitle(), onlineSuccesButton: self.getButtonTitle()))
            }
        } else {
            self.view?.displaySubview(subview: .success, params: SubviewParams(header: nil, title: nil, message: getFailureMessage(), continueButton: true, doItLater: true, IncetiveMessage: "", okButton: true, successImage: getStatusImage(value: false), doneButton: false, retryButton: false))
        }
    }
    
    func updateProgressValue(progressValue: Float) {
        self.view?.updateProgressBar(progress: Float(progressValue))
    }
    
    func updateStepMessage(stepMessage: String) {
        
    }
    
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep) {
        
    }
    
    func updateSuccessType(successType: OrderFetchSuccessType) {
        
    }
    
    func onServicesDown(error: ASLException?) {
        
    }
    
    func updateScrapeProgressPercentage(value: Int) {
        self.view?.updatePercentage(percentage:value)
    }
    
    func updateProgressHeaderLabel(isUploadingPreviousOrder: Bool) {
        if let account = self.getAccountByScrapingIndex(scrapingIndex: currentScrapingIndex) {
            self.setHeader(isUploadingPreviousOrders: isUploadingPreviousOrder, orderSource: account.source.value)
        }
       
    }
}
