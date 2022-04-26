//
//  OnlineScrapingController.swift
//  OrderScrapper
//
//  Created by Avinash Mohanta on 23/02/22.
//

import Foundation
import UIKit
import WebKit

enum SubView {
    case progress, success, networkError, error, timeout, onlineSuccess
}

struct SubviewParams {
    var header: String?
    var title: String?
    var message: String?
    var continueButton: Bool?
    var doItLater: Bool?
    var IncetiveMessage: String?
    var okButton: Bool?
    var successImage: UIImage?
    var doneButton: Bool?
    var retryButton: Bool?
    var onlineSuccesMessage: String?
    var onlineSuccesButton: String?
}

/**
 The view component to show the online scraping view
 */
protocol OnlineScrapingView {
    func setHeaderTitle(title: String)
    
    func updateProgressBar(progress: Float)
    
    func updatePercentage(percentage: Int)
    
    func displaySubview(subview: SubView, params: SubviewParams?)
    
    func goBackToPreviousScreen()
    
    func getWebClient() -> BSWebClient
}

class OnlineScrapingController: UIViewController, BSWebNavigationObserver {
    
    private var presenter: OnlineScrapingPresenter!
    var connectAccountView: ConnectAccountView!
    var accounts: [Account] = []
    var webClient: BSWebClient!
    let webClientDelegate = BSWebNavigationDelegate()
    var shouldAllowBack: Bool = false
    
    override func viewDidLoad() {
        self.setupWebClient()
        presenter = OnlineScrapingPresenterImpl(accounts: accounts)
        self.setupProgressView()
    }
    
    deinit {
        print("!!!! deinit called")
    }
    override func viewWillAppear(_ animated: Bool) {
        presenter?.attachView(view: self)
        presenter?.beginScraping()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("!!!! viewDidDisappear called")
        self.presenter?.detachView()
    }
    //MARK: - Public Methods
    
    func didFinishPageNavigation(url: URL?) {
        //
    }
    
    func didStartPageNavigation(url: URL?) {
        //
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        //
    }
    
    //MARK: - Private Methods
    
    private func displayProgressView(params: SubviewParams?) {
        DispatchQueue.main.async {
            self.shouldAllowBack = false
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.progressView)
        }
    }
    
    private func displaySuccessView(params: SubviewParams?) {
        DispatchQueue.main.async {
            self.connectAccountView.successView.fetchSuccessMessage.text = params?.message ?? ""
            self.connectAccountView.successView.okButton.isHidden = params?.okButton ?? false
            self.connectAccountView.successView.continueButton.isHidden = params?.continueButton ?? true
            self.connectAccountView.successView.cancelButton.isHidden = params?.doItLater ?? true
            self.connectAccountView.successView.imageView = params?.successImage ?? Utils.getImage(named: IconNames.SuccessScreen)!
            self.shouldAllowBack = true
            self.connectAccountView.successView.retryButton.isHidden = params?.retryButton ?? true
            self.connectAccountView.successView.doneButton.isHidden = params?.doneButton ?? true
            self.connectAccountView.successView.incentiveMessage.text = params?.IncetiveMessage ?? ""
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.successView)
        }
    }
    
    private func displayErrorView(params: SubviewParams?) {
        
    }
    
    private func displayNetworkErrorView(params: SubviewParams?) {
        DispatchQueue.main.async {
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.networkErrorView)
        }
    }
    
    private func displayTimeoutView(params: SubviewParams?) {
        DispatchQueue.main.async {
            self.connectAccountView.fetchSuccess = params!.message!
            self.connectAccountView.successView.continueButton.isHidden = params!.continueButton!
            self.connectAccountView.successView.cancelButton.isHidden = params!.doItLater!
            self.connectAccountView.successView.incentiveMessage.text = params?.IncetiveMessage ?? ""
            self.connectAccountView.successView.okButton.isHidden = params!.okButton!
            self.shouldAllowBack = true
            self.connectAccountView.successView.doneButton.isHidden = params!.doneButton ?? true
            self.connectAccountView.successView.retryButton.isHidden = params!.doneButton ?? true
            self.connectAccountView.successView.imageView = params!.successImage!
            self.connectAccountView.bringSubviewToFront(self.connectAccountView.successView)
        }
    }
    
    private func displayOnlineSuccessView(params: SubviewParams?) {
        DispatchQueue.main.async {
            print("!!!! displayOnlineSuccessView",params?.onlineSuccesButton)
            self.shouldAllowBack = true
            self.connectAccountView.onlineSuccessView.successMessage.text = params?.message ?? ""
            self.connectAccountView.onlineSuccessView.successNoteMessage.text = params?.IncetiveMessage ?? ""
            self.connectAccountView.onlineSuccessView.successHeader.text = params?.onlineSuccesMessage ?? ""
            self.connectAccountView.onlineSuccessView.okButton.setTitle(params?.onlineSuccesButton, for: .normal)
            self.connectAccountView.bringSubviewToFront(self.connectAccountView.onlineSuccessView)
        }
    }
    
    private func setupProgressView() {
        DispatchQueue.main.async {
            self.connectAccountView = ConnectAccountView(frame: self.view.bounds)
            self.connectAccountView.delegate = self
            self.connectAccountView?.connectAccountTitle.text =  "Update Online Orders"
            self.connectAccountView.stepText = ""
            self.shouldAllowBack = false
            
            self.view.addSubview(self.connectAccountView)
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
    
    private func cleanUp() {
        self.webClient.navigationDelegate = nil
        self.connectAccountView.delegate = nil
        self.webClientDelegate.removeObserver()
    }
}

extension OnlineScrapingController: OnlineScrapingView {
    func getWebClient() -> BSWebClient {
        return self.webClient
    }
    
    func displaySubview(subview: SubView, params: SubviewParams?) {
        DispatchQueue.main.async {
            switch subview {
            case .progress:
                self.displayProgressView(params: params)
            case .success:
                self.displaySuccessView(params: params)
            case .networkError:
                self.displayNetworkErrorView(params: params)
            case .error:
                self.displayErrorView(params: params)
            case .timeout:
                self.displayTimeoutView(params: params)
            case .onlineSuccess:
                self.displayOnlineSuccessView(params: params)
            }
        }
    }
    
    func goBackToPreviousScreen() {
        if shouldAllowBack {
            DispatchQueue.main.async {
                self.cleanUp()
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func setHeaderTitle(title: String) {
        DispatchQueue.main.async {
            self.connectAccountView.headerText = title
            self.connectAccountView.progressView.scrapePercentage.text = ""
        }
    }
    
    func updateProgressBar(progress: Float) {
        DispatchQueue.main.async {
            let progress = progress / AppConstants.progressValue
            print("!!!! updateProgressValue for progress bar",progress)
            self.connectAccountView.progress = CGFloat(progress)
        }
    }
    
    func updatePercentage(percentage: Int) {
        DispatchQueue.main.async {
            //self.updateProgressBar(progress: Float(percentage))
            self.connectAccountView.scrapePercentage = "\(percentage) %"
        }
    }
}

extension OnlineScrapingController: ConnectAccountViewDelegate {
    func didTapTryAgain() {
        print("!!!! didTapTryAgain called")
        self.presenter.didClickButton(button: .scrapeAagain)
    }
    
    func didTapDone() {
        self.presenter.didClickButton(button: .done)
    }
    
    func didTapBackButton() {
        self.presenter.didClickButton(button: .back)
    }
    
    func didTapRetryOnError() {
        self.presenter.didClickButton(button: .retry)
    }
    
    func didTapRetryOnNetworkError() {
        self.presenter.didClickButton(button: .retry)
    }
    
    func didTapSuccessButton() {
        self.presenter.didClickButton(button: .ok)
    }
    
    func didTapCancelScraping() {
        
    }
    
    func didTapScrapeLater() {
        self.presenter.didClickButton(button: .doLater)
    }
    
    func didTapContinueScraping() {
        self.presenter.didClickButton(button: .continueOperation)
        self.displaySubview(subview: .progress, params: nil)
    }
    
}
