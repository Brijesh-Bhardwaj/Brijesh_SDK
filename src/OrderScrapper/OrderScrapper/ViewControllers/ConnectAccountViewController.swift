//
//  ConnectAccountViewController.swift
//  OrderScrapper
//

import UIKit
import WebKit
import Combine
import Network
import Sentry

class ConnectAccountViewController: UIViewController, ScraperProgressListener, TimerCallbacks {
    private let baseURL = "https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=900&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fb2b%2Freports%2F"
    private let reportUrl = "https://www.amazon.com/gp/b2b/reports/"
    private let viewModel = WebViewModel()
    private var scraperListener: ScraperProgressListener!
    private var navigationHelper: NavigationHelper!
    private var path: NWPath?
    private var timerHandler: TimerHandler!
    private var viewInit = false
    private var isFetchSkipped: Bool = false
    private var isFailureButAccountConnected: Bool = false
    private var shouldAllowBack = false
    private var timerCallback: TimerCallbacks!
    private var networkState: NetworkState = .available
    let monitor = NWPathMonitor()
    var account: Account!
    var fetchRequestSource: FetchRequestSource?
    private var isTimeOut: Bool = false
    
    // MARK: - Subscribers
    private var jsSubscriber: AnyCancellable? = nil
    private var navigationSubscriber: AnyCancellable? = nil
    private var showWebViewSubscriber: AnyCancellable? = nil
    private var webViewErrorSubscriber: AnyCancellable? = nil
    private var authErrorSubscriber: AnyCancellable? = nil
    private var progressValueSubscriber: AnyCancellable? = nil
    private var progressMessageSubscriber: AnyCancellable? = nil
    private var headingMessageSubscriber: AnyCancellable? = nil
    private var stepMessageSubscriber: AnyCancellable? = nil
    private var completionSubscriber: AnyCancellable? = nil
    private var stopScrappingSubscriber: AnyCancellable? = nil
    private var authenticationCompleteSubscriber: AnyCancellable? = nil
    
    // MARK: - View References
    
    // MARK: - IBOutlets
    @IBOutlet weak var webContentView: WKWebView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var networkErrorView: NetworkErrorView!
    @IBOutlet weak var errorView: ErrorView!
    @IBOutlet weak var fetchSuccessView: FetchSuccessView!
    @IBOutlet weak var progressView: ProgressView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    // MARK: - Public Methods
    
    // MARK: - Lifecycle Methods
    deinit {
        self.jsSubscriber?.cancel()
        self.navigationSubscriber?.cancel()
        self.showWebViewSubscriber?.cancel()
        self.webViewErrorSubscriber?.cancel()
        self.authErrorSubscriber?.cancel()
        self.progressValueSubscriber?.cancel()
        self.progressMessageSubscriber?.cancel()
        self.headingMessageSubscriber?.cancel()
        self.stepMessageSubscriber?.cancel()
        self.completionSubscriber?.cancel()
        self.stopScrappingSubscriber?.cancel()
        self.removeNavigationDelegate()
        self.monitor.pathUpdateHandler = nil
        self.monitor.cancel()
        self.authenticationCompleteSubscriber?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.headerLabel?.text = getHeaderTitle()
        self.progressView?.headerText = getHeaderMessage(isUploadingPreviousOrder: false)
        if let statusImage = self.getStatusImage() {
            self.fetchSuccessView?.imageView = statusImage
        }
        if self.fetchRequestSource == .manual || self.fetchRequestSource == .online {
            self.progressView?.hideCancelScrapeBtn = false
        }
        self.scraperListener = self
        
        self.timerCallback = self
        
        self.initNetworkMonitor()
        
        self.viewModel.userAccount = self.account
        
        self.webContentView.navigationDelegate = self
        
        self.timerHandler = TimerHandler(timerCallback: self.timerCallback)
        
        self.navigationHelper = AmazonNavigationHelper(self.viewModel, webView: self.webContentView
                                                       , scraperListener: scraperListener, timerHandler: self.timerHandler, fetchRequestSource: fetchRequestSource)
        
        self.webContentView.evaluateJavaScript("navigator.userAgent") { [weak self] (agent, error) in
            guard let self = self else { return }
            
            var userAgent = "iPhone;"
            if let agent = agent as? String {
                userAgent = agent.replacingOccurrences(of: "iPad", with: "iPhone")
            } else {
                print(AppConstants.tag, "evaluateJavaScript", error.debugDescription)
                if let error = error {
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                          EventConstant.EventName: EventType.ErrorWhileEvaluatingJS,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                
            }
            self.webContentView.customUserAgent = userAgent
            if let url = URL(string: self.baseURL) {
                self.timerHandler?.startTimer(action: Actions.BaseURLLoading)
                self.webContentView?.load(URLRequest(url: url))
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_ejs_loadurl \(url)")
            }
        }
        
        self.registerSubscribers()
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_viewDidLoad")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.initViews()
        viewInit = true
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_viewWillAppear")
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = self.contentView.bounds.width * 0.1
        self.contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    // MARK: - IBActions
    @IBAction func didClickBackButton(_ sender: Any) {
        if self.shouldAllowBack {
            self.webContentView?.stopLoading()
            LibContext.shared.scrapeCompletionPublisher.send(((false, nil), ASLException(errorMessage: Strings.ErrorUserAbortedProcess, errorType: ErrorType.userAborted)))
            WebCacheCleaner.clear(completionHandler: nil)
            self.dismiss(animated: true, completion: nil)
            
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                  EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.UserAbortedProcess, eventAttributes: logEventAttributes)
        }
    }
    
    // MARK: - Private Methods
    private func initNetworkMonitor() {
        let queue = DispatchQueue(label: "Monitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.path = path
            // Monitor runs on a background thread so we need to publish
            // on the main thread
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self.networkState != .available {
                        self.networkState = .available
                        self.onNetworkConnected()
                    }
                } else {
                    if self.networkState != .notAvailable {
                        self.networkState = .notAvailable
                        self.onNetworkDisconnected()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func onNetworkConnected() {
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_network_satisfied")
        if self.viewInit {
            self.loadWebContent()
        }
    }
    
    private func onNetworkDisconnected() {
        self.navigationHelper.isGenerateReport = false
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_network_not_satisfied")
        self.contentView.bringSubviewToFront(self.networkErrorView)
        self.shouldAllowBack = true
        if let navigationHelper = self.navigationHelper {
            let scraper = navigationHelper.backgroundScrapper
            if let scraper = scraper {
                scraper.stopScrapping()
            }
        }
        if fetchRequestSource == .manual || fetchRequestSource == .online {
            DispatchQueue.main.async {
                self.progressView?.scrapePercentage.text = ""
            }
        }
    }
    
    private func hasNetwork() -> Bool {
         if let path = self.path {
            if path.status == NWPath.Status.satisfied {
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_hasNetwork()_satisfied")
                return true
            }
        }
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_hasNetwork()_Not_satisfied")
        return false
    }
    
    private func initViews() {
        self.errorView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.buttonClickHandler()
        }
        self.networkErrorView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.buttonClickHandler()
        }
        self.fetchSuccessView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.successHandler()
        }
        self.progressView.buttonClickHandler = {[weak self] in
            guard let self = self else { return }
            self.cancelManualScrape()
        }
        self.fetchSuccessView.scrapeLaterClickHandler = {[weak self] in
            guard let self = self else { return }
            self.cancelManualScrape()
        }
        self.fetchSuccessView.scrapeContinueClickHandler = {[weak self] in
            guard let self = self else { return }
            self.continueManualScraping()
        }
    }
    
    private func hideWebContents(hide: Bool) {
        self.webContentView?.isHidden = hide
        if hide {
            self.containerView?.isHidden = false
            self.view.bringSubviewToFront(self.containerView)
        } else {
            self.containerView?.isHidden = true
            self.view.bringSubviewToFront(self.webContentView)
        }
    }
    
    private func hideProgressContents(hide: Bool) {
        self.containerView.isHidden = hide
        if !hide {
            self.view.bringSubviewToFront(self.containerView)
        }
    }
    
    private func registerSubscribers() {
        /* An observer that observes 'viewModel.jsPublisher' to get javascript value and
         pass that value to web app by calling JavaScript function */
        jsSubscriber = viewModel.jsPublisher.receive(on: RunLoop.main).sink(receiveValue: {
            [weak self] (authState, javascript) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.webContentView.evaluateJavaScript(javascript) {
                    [weak self] (response, error) in
                    guard let self = self else { return }
                    self.viewModel.jsResultPublisher.send((authState, (response, error)))
                    
                    //Log events for JS injection
                    var logEventAttributes:[String:String] = [:]
                    var status: String
                    if error == nil {
                        status = EventStatus.Success
                    } else {
                        status = EventStatus.Failure
                        print(AppConstants.tag, "evaluateJavaScript", error.debugDescription)
                        if let error = error {
                            var logErrorEventAttributes:[String:String] = [:]
                            logErrorEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                       EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                                       EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                                       EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                                       EventConstant.Status: status,
                                                       EventConstant.JSInjectType: authState.value,
                                                       EventConstant.EventName: EventType.ErrorWhileEvaluatingJS]
                            FirebaseAnalyticsUtil.logSentryError(eventAttributes: logErrorEventAttributes, error: error)
                        }
                    }
                    switch authState {
                    case .email:
                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
                    case .password:
                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectPassword, eventAttributes: logEventAttributes)
                    case .captcha:
                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                    case .generateReport:
                        self.timerHandler?.stopTimer()
                        //Logging event for report generation
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.OrderSource:              OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportGeneration, eventAttributes: logEventAttributes)
                    case .downloadReport:
                        self.timerHandler?.stopTimer()
                        //Logging event for report download
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.OrderSource:                    OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectReportDownload, eventAttributes: logEventAttributes)
                    case .dateRange, .identification, .error:break
                    }
                }
            }
        })
        
        navigationSubscriber = self.viewModel.navigationPublisher.receive(on: RunLoop.main).sink(receiveValue: {
            [weak self] navigation in
            guard let self = self else { return }
            switch navigation {
            case .reload:
                if let url = URL(string: self.baseURL) {
                    self.webContentView?.load(URLRequest(url: url))
                    FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_reload_url \(url)")
                }
            }
        })
        
        showWebViewSubscriber = self.viewModel.showWebView.receive(on: RunLoop.main).sink(receiveValue: { [weak self] showWeb in
            guard let self = self else { return }
            self.hideWebContents(hide: !showWeb)
            if showWeb {
                self.timerHandler?.stopTimer()
            }
        })
        webViewErrorSubscriber = self.viewModel.webviewError.receive(on: RunLoop.main).sink(receiveValue: { [weak self] isWebError in
            guard let self = self else { return }
            if isWebError {
                if self.hasNetwork() {
                    self.contentView.bringSubviewToFront(self.errorView)
                } else {
                    self.contentView.bringSubviewToFront(self.networkErrorView)
                }
                self.shouldAllowBack = true
            }
        })
        authErrorSubscriber = self.viewModel.authError.receive(on: RunLoop.main).sink(receiveValue: { [weak self] isError in
            guard let self = self else { return }
            if isError.0 {
                self.timerHandler?.stopTimer()
                LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
                WebCacheCleaner.clear(completionHandler: nil)
                self.dismiss(animated: true, completion: nil)
            }
        })
        progressValueSubscriber = self.viewModel.progressValue.receive(on: RunLoop.main).sink(receiveValue: { [weak self] progress in
            guard let self = self else { return }
            self.contentView?.bringSubviewToFront(self.progressView)
            self.progressView?.progress = CGFloat(progress)
            //Progress
        })
        progressMessageSubscriber = self.viewModel.progressMessage.receive(on: RunLoop.main).sink(receiveValue: { message in
        })
        headingMessageSubscriber = self.viewModel.headingMessage.receive(on: RunLoop.main).sink(receiveValue: { headerMessage in
        })
        stepMessageSubscriber = self.viewModel.stepMessage.receive(on: RunLoop.main).sink(receiveValue: { [weak self] stepMessage in
            guard let self = self else { return }
            if !stepMessage.elementsEqual(self.progressView.stepText) {
                self.contentView?.bringSubviewToFront(self.progressView)
                self.progressView?.stepText = stepMessage
            }
        })
        completionSubscriber = self.viewModel.completionPublisher.receive(on: RunLoop.main).sink(receiveValue: { [weak self] complete in
            guard let self = self else { return }
            if complete {
                self.backButton?.isEnabled = false
                self.backButton?.isHidden = true
                self.fetchSuccessView?.fetchSuccess = self.getSuccessMessage()
                if let statusImage = self.getStatusImage() {
                    self.fetchSuccessView?.imageView = statusImage
                }
                self.fetchSuccessView.successIncentiveMessage = self.getIncentiveSuccessMessage()
                self.contentView?.bringSubviewToFront(self.fetchSuccessView)
            }
        })
        stopScrappingSubscriber = self.viewModel.disableScrapping.receive(on: RunLoop.main).sink(receiveValue: { [weak self] disable in
            guard let self = self else { return }
            self.isFetchSkipped = disable
            if disable {
                self.backButton?.isEnabled = false
                self.backButton?.isHidden = true
                self.fetchSuccessView?.fetchSuccess = self.getSuccessMessage()
                if let statusImage = self.getStatusImage() {
                    self.fetchSuccessView?.imageView = statusImage
                }
                self.fetchSuccessView.successIncentiveMessage = self.getIncentiveSuccessMessage()
                self.contentView?.bringSubviewToFront(self.fetchSuccessView)
            }
        })
        authenticationCompleteSubscriber = self.viewModel.authenticationComplete.receive(on: RunLoop.main).sink(receiveValue: { [weak self] authenticated in
            guard let self = self else { return }
            if authenticated {
                if let url = URL(string: self.reportUrl) {
                    self.webContentView?.load(URLRequest(url: url))
                }
            }
        })
    }
    
    private func loadWebContent() {
        if let url = URL(string: self.baseURL) {
            self.webContentView?.load(URLRequest(url: url))
            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_loadWebContent() \(url)")
        }
        self.contentView?.bringSubviewToFront(self.progressView)
        self.progressView?.progress = 1/6
        self.progressView?.stepText = Utils.getString(key: Strings.Step1)
        self.shouldAllowBack = false
    }
    
    private func buttonClickHandler() {
        if hasNetwork() {
            loadWebContent()
            self.shouldAllowBack = false
        }
    }
    
    private func successHandler() {
        self.removeNavigationDelegate()
        if self.isFetchSkipped {
            let result = (true, OrderFetchSuccessType.fetchSkipped)
            LibContext.shared.scrapeCompletionPublisher.send((result, ASLException(errorMessage: Strings.ExtractionDisabled, errorType: nil) ))
        } else if self.isFailureButAccountConnected {
            let result = (true, OrderFetchSuccessType.failureButAccountConnected)
            LibContext.shared.scrapeCompletionPublisher.send((result, nil))
        } else {
            let result = (true, OrderFetchSuccessType.fetchCompleted)
            LibContext.shared.scrapeCompletionPublisher.send((result, nil))
        }
    }
    
    private func logEvents(logEvents: EventLogs) {
        _ = AmazonService.logEvents(eventLogs: logEvents, orderSource: self.viewModel.userAccount.source.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                print("#### servicesDown")
                self.handleServicesDown()
            }
        }
    }
    
    private func logEventss(failureType: String, eventState: String, scrapingType: String?) {
        let eventLogs = EventLogs(panelistId: self.account.panelistID, platformId:self.account.userID, section: SectionType.connection.rawValue, type: failureType, status: eventState, message: AppConstants.msgTimeout, fromDate: nil, toDate: nil, scrapingType: scrapingType, scrapingContext: ScrapingMode.Foreground.rawValue)

        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.viewModel.userAccount.source.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                print("#### servicesDown")
                self.handleServicesDown()
            }
        }
    }
    
    func removeNavigationDelegate() {
        self.webContentView?.navigationDelegate = nil
    }
    
    func onWebviewError(isError: Bool) {
        DispatchQueue.main.async {
            if isError {
                if self.hasNetwork() {
                    self.contentView?.bringSubviewToFront(self.errorView)
                } else {
                    self.contentView?.bringSubviewToFront(self.networkErrorView)
                }
                self.shouldAllowBack = true
            }
        }
    }
    
    func updateProgressValue(progressValue: Float) {
        DispatchQueue.main.async {
            self.contentView?.bringSubviewToFront(self.progressView)
            self.progressView?.progress = CGFloat(progressValue)
        }
    }
    
    func updateStepMessage(stepMessage: String) {
        DispatchQueue.main.async {
            if !stepMessage.elementsEqual(self.progressView.stepText) {
                self.contentView?.bringSubviewToFront(self.progressView)
                self.progressView?.stepText = stepMessage
            }
        }
    }
    
    func updateSuccessType(successType: OrderFetchSuccessType) {
        switch successType {
        case .fetchSkipped:
            self.isFetchSkipped = true
        case .failureButAccountConnected:
            self.isFailureButAccountConnected = true
        case .fetchCompleted:
            print("")
        case .fetchSkippedByUser:
            print("")
        }
    }
    
    func onCompletion(isComplete: Bool) {
        if isComplete {
            self.isTimeOut = false
            self.isFailureButAccountConnected = false
            self.isFetchSkipped = false
            DispatchQueue.main.async {
                self.backButton?.isEnabled = false
                self.backButton?.isHidden = true
                self.fetchSuccessView?.fetchSuccess = self.getSuccessMessage()
                self.fetchSuccessView?.hideOkButton = false
                self.fetchSuccessView?.hideCancelButton = true
                self.fetchSuccessView?.hideContinueButton = true
                if let statusImage = self.getStatusImage() {
                    self.fetchSuccessView?.imageView = statusImage
                }
                self.fetchSuccessView?.successIncentiveMessage = self.getIncentiveSuccessMessage()
                self.contentView?.bringSubviewToFront(self.fetchSuccessView)
            }
        } else {
            DispatchQueue.main.async {
                self.backButton?.isEnabled = false
                self.backButton?.isHidden = true
                self.isTimeOut = false
                self.fetchSuccessView?.fetchSuccess = self.getSuccessMessage()
                self.fetchSuccessView.successIncentiveMessage = true
                self.fetchSuccessView?.hideOkButton = false
                self.fetchSuccessView?.hideCancelButton = true
                self.fetchSuccessView?.hideContinueButton = true
                if let statusImage = self.getStatusImage() {
                    self.fetchSuccessView?.imageView = statusImage
                }
                self.contentView?.bringSubviewToFront(self.fetchSuccessView)
            }
        }
    }
    
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep) {
        let currentProgress = self.progressView.progress
        let remainingProgress = 1 - currentProgress
        var newProgressValue: Float = 0
        switch htmlScrappingStep {
        case .startScrapping:
            newProgressValue = Float(currentProgress) + Float(remainingProgress)/3
            updateStepMessage(stepMessage: "Step 3")
        case .listing:
            newProgressValue = Float(currentProgress) + Float(remainingProgress)/2
            updateStepMessage(stepMessage: "Step 4")
        case .complete:
            newProgressValue = Float(currentProgress) + Float(remainingProgress)/1
            updateStepMessage(stepMessage: "Step 5")
        }
        updateProgressValue(progressValue: newProgressValue)
    }
    
    func onTimerTriggered(action: String) {
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_onTimerTriggered() \(action)")
        
        if action == Actions.GetOldestPossibleYearJSCallback ||
            action == Actions.DownloadReportJSInjection ||
            action == Actions.ReportGenerationJSCallback ||
            action == Actions.ForegroundHtmlScrapping ||
            action == Actions.ForegroundCSVScrapping {
            
            self.isFailureButAccountConnected = true
            
            // On timeout cancel all the ongoing API calls
            AmazonService.cancelAPI()
            
            //Timeout happens and if account is connected
            //then update order status as failed in the backend
            //TODO :- Check orderSource in case of instacart
            let amazonId = self.viewModel.userAccount.userID
            _ = AmazonService.updateStatus(platformId: amazonId,
                                           status: AccountState.Connected.rawValue,
                                           message: AppConstants.msgTimeout,
                                           orderStatus: OrderStatus.Failed.rawValue, orderSource: OrderSource.Amazon.value) { response, error in
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    print("#### servicesDown")
                    self.handleServicesDown()
                }
            }
            if (self.fetchRequestSource == .manual || self.fetchRequestSource == .online) && action == Actions.ForegroundHtmlScrapping {
                logEventss(failureType: FailureTypes.timeout.rawValue, eventState: EventState.fail.rawValue, scrapingType: ScrappingType.html.rawValue)
            } else if (action == Actions.ForegroundHtmlScrapping) {
                self.webContentView?.stopLoading()
                self.webContentView?.navigationDelegate = nil
                logEventss(failureType: FailureTypes.timeout.rawValue, eventState: EventState.fail.rawValue, scrapingType: ScrappingType.html.rawValue)
            } else {
                logEventss(failureType: FailureTypes.timeout.rawValue, eventState: EventState.fail.rawValue, scrapingType: ScrappingType.report.rawValue)
            }
            //On timeout show error on success view. For manual scrapping show 'Contunue' and 'Do It Later' buttons
            showSuccessView(action: action)
        } else {
            self.timerHandler?.stopTimer()
            logEventss(failureType: FailureTypes.authentication.rawValue, eventState: EventState.success.rawValue, scrapingType: nil)
            LibContext.shared.webAuthErrorPublisher.send((true, AppConstants.msgTimeout))
            WebCacheCleaner.clear(completionHandler: nil)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func getHeaderTitle() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual  {
            return String.init(format: Strings.HeaderFetchOrders, OrderSource.Amazon.value)
        } else if source == .online{
            return Strings.OnlineHeaderFetchingOrders
        }else {
            return Utils.getString(key: Strings.HeadingConnectAmazonAccount)
        }
    }
    
    private func getHeaderMessage(isUploadingPreviousOrder: Bool) -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if isUploadingPreviousOrder {
                return String.init(format: Strings.HeaderFetchingPendingOrders, OrderSource.Amazon.value)
            } else {
                return String.init(format: Strings.HeaderFetchingOrders, OrderSource.Amazon.value)
            }
        } else if source == .online {
            if isUploadingPreviousOrder {
                return Strings.OnlineHeaderPendingFetchingOrders
            } else {
                return Strings.OnlineFetchingOrders
            }
        } else {
            return Utils.getString(key: Strings.HeadingConnectingAmazonAccount)
        }
    }
    
    private func getSuccessMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if isTimeOut {
                return LibContext.shared.manualScrapeTimeOutMessage
            } else if isFetchSkipped || isFailureButAccountConnected {
                return String.init(format: Strings.FetchFailureMessage, OrderSource.Amazon.value)
            } else {
                return LibContext.shared.manualScrapeSuccess
            }
        } else if source == .online {
            if isTimeOut {
                return Strings.OnlineTimeOutFailureMessage
            } else if isFetchSkipped || isFailureButAccountConnected {
                return Strings.OnlineFetchFailureMessage
            } else {
                return Strings.OnlineSuccessMessage
            }
        } else {
            return AppConstants.amazonAccountConnectedSuccess
        }
    }
    
    private func getIncentiveSuccessMessage() -> Bool {
        let source = self.fetchRequestSource ?? .general
        if source == .online {
            return false
        } else {
            return true
        }
    }
    
    //TODO:- Need to change
    private func getSuccessMessage(action: String) -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual  {
            if isTimeOut {
                if action == Actions.ForegroundHtmlScrapping {
                    return LibContext.shared.manualScrapeTimeOutMessage
                } else {
                    return String.init(format: Strings.FetchFailureMessage, OrderSource.Amazon.value)
                }
            } else if isFetchSkipped || isFailureButAccountConnected {
                return String.init(format: Strings.FetchFailureMessage, OrderSource.Amazon.value)
            } else {
                return String.init(format: Strings.FetchSuccessMessage, OrderSource.Amazon.value)
            }
        } else if source == .online {
            if isTimeOut {
                if action == Actions.ForegroundHtmlScrapping {
                    return Strings.OnlineTimeOutFailureMessage
                } else {
                    return Strings.OnlineFetchFailureMessage
                }
            } else if isFetchSkipped || isFailureButAccountConnected {
                return Strings.OnlineFetchFailureMessage
            } else {
                return Strings.OnlineSuccessMessage
            }
            
        } else {
            return AppConstants.amazonAccountConnectedSuccess
        }
    }
    
    private func getStatusImage() -> UIImage? {
        let source = self.fetchRequestSource ?? .general
        if source == .manual || source == .online {
            if isTimeOut  {
                return Utils.getImage(named: IconNames.SuccessScreen)
            } else if isFetchSkipped || isFailureButAccountConnected {
                return Utils.getImage(named: IconNames.FailureScreen)
            } else {
                return Utils.getImage(named: IconNames.SuccessScreen)
            }
        } else {
            return Utils.getImage(named: IconNames.SuccessScreen)
        }
    }
    
    private func getStatusImage(action: String) -> UIImage? {
        let source = self.fetchRequestSource ?? .general
        if source == .manual || source == .online {
            if isTimeOut  {
                if action == Actions.ForegroundHtmlScrapping {
                    return Utils.getImage(named: IconNames.SuccessScreen)
                } else {
                    return Utils.getImage(named: IconNames.FailureScreen)
                }
            } else if isFetchSkipped || isFailureButAccountConnected {
                return Utils.getImage(named: IconNames.FailureScreen)
            } else if isTimeOut {
                return Utils.getImage(named: IconNames.SuccessScreen)
            } else {
                return Utils.getImage(named: IconNames.SuccessScreen)
            }
        } else {
            return Utils.getImage(named: IconNames.SuccessScreen)
        }
    }

    func onServicesDown(error: ASLException?) {
        self.handleServicesDown()
    }
    
    func handleServicesDown() {
        self.webContentView.stopLoading()
        let isError: (Bool, String) = (true, Strings.ErrorServicesDown)
        LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
        WebCacheCleaner.clear(completionHandler: nil)
        self.dismiss(animated: true, completion: nil)
        self.timerHandler?.stopTimer()
        let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
        LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
    }
    
    func updateScrapeProgressPercentage(value: Int) {
        DispatchQueue.main.async {
            self.progressView?.scrapePercentage.text = "\(value) %"
        }
    }
    
    private func cancelManualScrape() {
        if self.navigationHelper.backgroundScrapper != nil {
            self.navigationHelper.backgroundScrapper.stopScrapping()
            self.navigationHelper.backgroundScrapper.scraperListener = nil
            self.navigationHelper.backgroundScrapper = nil
        }
        let result = (true, OrderFetchSuccessType.fetchSkippedByUser)
        LibContext.shared.scrapeCompletionPublisher.send((result, nil))
    }
    
    private func continueManualScraping() {
        print("##### $$ didTapContinueScraping")
        self.isTimeOut = false
        reStartTimerManualScraping()
        self.contentView?.bringSubviewToFront(self.progressView)
    }
    
    private func reStartTimerManualScraping() {
        self.getTimerValue(type: .html) { timerValue in
            self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: TimeInterval(timerValue))
        }
    }
    
    private func showSuccessView(action: String) {
        DispatchQueue.main.async {
            self.isTimeOut = true
            self.backButton?.isEnabled = false
            self.backButton?.isHidden = true
            self.fetchSuccessView?.fetchSuccess = self.getSuccessMessage(action: action)
            if let statusImage = self.getStatusImage(action: action) {
                self.fetchSuccessView?.imageView = statusImage
            }
            if self.fetchRequestSource == .manual || self.fetchRequestSource == .online {
                self.fetchSuccessView?.successIncentiveMessage = true
                self.fetchSuccessView?.hideOkButton = true
                self.fetchSuccessView?.hideCancelButton = false
                self.fetchSuccessView?.hideContinueButton = false
            } else {
                self.fetchSuccessView?.successIncentiveMessage = true
                self.fetchSuccessView?.hideOkButton = false
                self.fetchSuccessView?.hideCancelButton = true
                self.fetchSuccessView?.hideContinueButton = true
               
            }
            self.contentView?.bringSubviewToFront(self.fetchSuccessView)
        }
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
    
    func updateProgressHeaderLabel(isUploadingPreviousOrder: Bool) {
        DispatchQueue.main.async {
            self.progressView?.headerText = self.getHeaderMessage(isUploadingPreviousOrder: isUploadingPreviousOrder)
        }
    }
}

extension ConnectAccountViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("######: didFinish ",webView.url as Any)
        self.navigationHelper.navigateWith(url: webView.url)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Shows loader
        let showWebView = self.navigationHelper.shouldShowWebViewFor(url: webView.url)
        self.viewModel.showWebView.send(showWebView)
        self.timerHandler?.startTimer(action: Actions.DidStartProvisionalNavigation)
        
        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_VC_didStartProvisionalNavigation- \(webView.url as Any)")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,"An error occurred during navigation", error.localizedDescription)
        
        var logEventAttributes:[String:String] = [:]

        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let userId = self.account.userID
        logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                              EventConstant.PanelistID: panelistId,
                              EventConstant.OrderSourceID: userId,
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.EventName: EventType.DidFailPageNavigation,
                              EventConstant.Status: EventStatus.Failure]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,"An error occurred during the early navigation process", error.localizedDescription)
        var logEventAttributes:[String:String] = [:]

        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let userId = self.account.userID
        logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                              EventConstant.PanelistID: panelistId,
                              EventConstant.OrderSourceID: userId,
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.EventName: EventType.DidFailProvisionalNavigation,
                              EventConstant.Status: EventStatus.Failure]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print(AppConstants.tag, "webViewWebContentProcessDidTerminate()")
        var logEventAttributes:[String:String] = [:]

        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let userId = self.account.userID
        logEventAttributes = [EventConstant.OrderSource:OrderSource.Amazon.value,
                              EventConstant.PanelistID: panelistId,
                              EventConstant.OrderSourceID: userId,
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.EventName: EventType.WebContentProcessDidTerminate,
                              EventConstant.Status: EventStatus.Failure]
        if let url = webView.url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.WebContentProcessDidTerminate, eventAttributes: logEventAttributes)
        
    }
}
