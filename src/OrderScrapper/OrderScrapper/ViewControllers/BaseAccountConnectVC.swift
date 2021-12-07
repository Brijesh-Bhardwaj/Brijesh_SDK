//
//  BaseAccountConnectVC.swift
//  OrderScrapper
//

import UIKit
import Network
import WebKit

class BaseAccountConnectVC: UIViewController, BSWebNavigationObserver, TimerCallbacks {
    
    private let monitor = NWPathMonitor()
    private var path: NWPath?
    
    var account: Account!
    var shouldAllowBack = false
    var webClient: BSWebClient!
    var connectAccountView: ConnectAccountView!
    let webClientDelegate = BSWebNavigationDelegate()
    var baseAuthenticator: BSBaseAuthenticator!
    var networkReconnct = false
    var retryCount = 0
    private var networkState: NetworkState = .available
    var successType: OrderFetchSuccessType?
    var fetchRequestSource: FetchRequestSource!
    lazy var timerHandler: TimerHandler = {
        return TimerHandler(timerCallback: self)
    }()
    
    //MARK:- Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupNetworkMonitor()
        self.setupSubViews()
    }
    
    deinit {
        monitor.pathUpdateHandler = nil
        monitor.cancel()
    }
    
    //MARK:- Public Methods
    
    func hasNetwork() -> Bool {
        if let path = self.path {
            if path.status == NWPath.Status.satisfied {
                return true
            }
        }
        return false
    }
    
    //MARK:- Protected Methods
    
    func onNetworkChange(isNetworkAvailable: Bool) {
        // Can be overriden by subclasses
    }
    
    func didFinishPageNavigation(url: URL?) {
        
    }
    
    func didStartPageNavigation(url: URL?) {
        
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        
    }
    
    func loadWebContent() {
        
    }
    
    func shouldShowWebView(showWebView: Bool) {
        
    }
    
    func onTimerTriggered(action: String) {
       
    }
    //MARK:- Private Methods
    
    private func setupNetworkMonitor() {
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
                        self.onNetworkChange(isNetworkAvailable: true)
                    }
                } else {
                    if self.networkState != .notAvailable {
                        self.networkState = .notAvailable
                        self.onNetworkChange(isNetworkAvailable: false)
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func setupSubViews() {
        self.setupWebClient()
        self.setupConnectAccountView()
        
        switch account.source {
        case .Amazon:
            self.connectAccountView.headerText = "Connect Amazon Account"
        case .Instacart:
            self.connectAccountView.headerText = "Connect Instacart Account"
        case .Kroger:
            self.connectAccountView.headerText = "Connect Kroger Account"
        case .Walmart:
            self.connectAccountView.headerText = "Connect Walmart Account"
        }
    }
    
    private func setupWebClient() {
        let scriptMessageHandler = BSScriptMessageHandler()
        let contentController = WKUserContentController()
        contentController.add(scriptMessageHandler, name: "iOS")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        self.webClient = BSWebClient(frame: self.view.bounds, configuration: config, scriptMessageHandler: scriptMessageHandler)
        self.webClient.navigationDelegate = self.webClientDelegate
        self.webClientDelegate.setObserver(observer: self)
        
        self.view.addSubview(self.webClient)
    }
    
    private func setupConnectAccountView() {
        self.connectAccountView = ConnectAccountView(frame: self.view.bounds)
        self.connectAccountView.delegate = self
        
        self.view.addSubview(self.connectAccountView)
    }
}

extension BaseAccountConnectVC: ConnectAccountViewDelegate {
    func didTapBackButton() {
        if self.shouldAllowBack {
            self.timerHandler.stopTimer()
            LibContext.shared.scrapeCompletionPublisher.send(((false, nil), ASLException(errorMessage: Strings.ErrorUserAbortedProcess, errorType: ErrorType.userAborted)))
            WebCacheCleaner.clear(completionHandler: nil)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func didTapRetryOnError() {
        if self.hasNetwork() {
            loadWebContent()
            self.shouldAllowBack = false
        }
    }
    
    func didTapRetryOnNetworkError() {
        if self.hasNetwork() {
            print("!!!! didTapRetryOnNetworkError hasNetwork ")
            loadWebContent()
            self.shouldAllowBack = false
        }
    }
    
    func didTapSuccessButton() {
        let result = (true, self.successType ?? OrderFetchSuccessType.fetchCompleted)
        LibContext.shared.scrapeCompletionPublisher.send((result, nil))
    }
}


