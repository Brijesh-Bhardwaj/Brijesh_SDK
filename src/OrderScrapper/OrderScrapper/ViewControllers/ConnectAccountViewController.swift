//
//  ConnectAccountViewController.swift
//  OrderScrapper
//

import UIKit
import WebKit
import Combine
import Network

class ConnectAccountViewController: UIViewController {
    private let baseURL = "https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=900&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fb2b%2Freports%2F136-9723095-1427523%3Fie%3DUTF8%26%252AVersion%252A%3D1%26%252Aentries%252A%3D0"
    
    private let viewModel = WebViewModel()

    private var navigationHelper: NavigationHelper!
    
    var account: Account!
    
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.viewModel.userAccount = self.account
        
        self.webContentView.navigationDelegate = self
    
        self.webContentView.evaluateJavaScript("navigator.userAgent") { (agent, error) in
            var userAgent = "iPhone;"
            if let agent = agent as? String {
                userAgent = agent.replacingOccurrences(of: "iPad", with: "iPhone")
            }
            self.webContentView.customUserAgent = userAgent
            if let url = URL(string: self.baseURL) {
                self.webContentView.load(URLRequest(url: url))
            }
        }
        self.navigationHelper = AmazonNavigationHelper(self.viewModel)
        self.registerSubscribers()
        self.initViews()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = self.contentView.bounds.width * 0.1
        self.contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    // MARK: - Private Methods
    private func initNetworkMonitor() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "Monitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Monitor runs on a background thread so we need to publish
            // on the main thread
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.loadWebContent()
                } else {
                    self.contentView.bringSubviewToFront(self.networkErrorView)
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func initViews() {
        self.errorView.buttonClickHandler = buttonClickHandler
        self.networkErrorView.buttonClickHandler = buttonClickHandler
        self.fetchSuccessView.buttonClickHandler = successHandler
    }
    
    private func hideWebContents(hide: Bool) {
        self.webContentView.isHidden = hide
        if hide {
            self.containerView.isHidden = false
            self.view.bringSubviewToFront(self.containerView)
        } else {
            self.containerView.isHidden = true
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
            (authState, javascript) in
            self.webContentView.evaluateJavaScript(javascript) {
                (response, error) in
                self.viewModel.jsResultPublisher.send((authState, (response, error)))
                
                //Log events for JS injection
                var logEventAttributes:[String:String] = [:]
                var status: String
                if error == nil {
                    status = EventStatus.Success
                } else {
                    status = EventStatus.Failure
                }
                switch authState {
                case .email:
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.Status: status]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
                case .password:
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.Status: status]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectPassword, eventAttributes: logEventAttributes)
                case .captcha:
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                          EventConstant.Status: status]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                case .dateRange, .downloadReport, .generateReport, .identification, .error:break
                }
            }
        })
        
        navigationSubscriber = self.viewModel.navigationPublisher.receive(on: RunLoop.main).sink(receiveValue: {
            navigation in
            switch navigation {
            case .reload:
                if let url = URL(string: self.baseURL) {
                    self.webContentView.load(URLRequest(url: url))
                }
            }
        })
        
        showWebViewSubscriber = self.viewModel.showWebView.receive(on: RunLoop.main).sink(receiveValue: { showWeb in
            self.hideWebContents(hide: !showWeb)
        })
        webViewErrorSubscriber = self.viewModel.webviewError.receive(on: RunLoop.main).sink(receiveValue: { isWebError in
            if isWebError {
                self.contentView.bringSubviewToFront(self.errorView)
            }
        })
        authErrorSubscriber = self.viewModel.authError.receive(on: RunLoop.main).sink(receiveValue: { isError in
            if isError {
                LibContext.shared.webAuthErrorPublisher.send(isError)
                self.dismiss(animated: true, completion: nil)
            }
        })
        progressValueSubscriber = self.viewModel.progressValue.receive(on: RunLoop.main).sink(receiveValue: { progress in
            self.contentView.bringSubviewToFront(self.progressView)
            self.progressView.progress = CGFloat(progress)
            //Progress
        })
        progressMessageSubscriber = self.viewModel.progressMessage.receive(on: RunLoop.main).sink(receiveValue: { message in
            if !self.progressView.headerText.elementsEqual(message) {
                self.contentView.bringSubviewToFront(self.progressView)
                self.progressView.headerText = message
            }
        })
        headingMessageSubscriber = self.viewModel.headingMessage.receive(on: RunLoop.main).sink(receiveValue: { headerMessage in
            self.headerLabel.text = headerMessage
        })
        stepMessageSubscriber = self.viewModel.stepMessage.receive(on: RunLoop.main).sink(receiveValue: { stepMessage in
            if !stepMessage.elementsEqual(self.progressView.stepText) {
                self.contentView.bringSubviewToFront(self.progressView)
                self.progressView.stepText = stepMessage
            }
        })
        completionSubscriber = self.viewModel.completionPublisher.receive(on: RunLoop.main).sink(receiveValue: { complete in
            if complete {
                self.contentView.bringSubviewToFront(self.fetchSuccessView)
            }
        })
        stopScrappingSubscriber = self.viewModel.disableScrapping.receive(on: RunLoop.main).sink(receiveValue: { disable in
            if disable {
                self.dismiss(animated: true) {
                    LibContext.shared.scrapeCompletionPublisher.send((false, Strings.ExtractionDisabled))
                }
            }
        })
    }
    
    private func loadWebContent() {
        if let url = URL(string: self.baseURL) {
            self.webContentView.load(URLRequest(url: url))
        }
        self.progressView.progress = 1/6
        self.progressView.stepText = Utils.getString(key: Strings.Step1)
        self.contentView.bringSubviewToFront(self.progressView)
    }
    
    private func buttonClickHandler() {
        loadWebContent()
    }
    
    private func successHandler() {
        self.dismiss(animated: true) {
            LibContext.shared.scrapeCompletionPublisher.send((true, nil))
        }
    }
}

extension ConnectAccountViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.navigationHelper.navigateWith(url: webView.url)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Shows loader
        self.viewModel.showWebView.send(false)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if (self.navigationHelper.shouldIntercept(navigationResponse: navigationResponse.response)) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                self.navigationHelper.intercept(navigationResponse: navigationResponse.response, cookies: cookies)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    // This function is essential for intercepting every navigation in the webview
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = .mobile
        decisionHandler(.allow, preferences)
    }
}
