//  BSBaseAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit
import Sentry

protocol BSAuthenticaorDelegate {
    func didReceiveAuthenticationChallenge(authError: Bool)
    func didReceiveProgressChange(step: Steps)
    func didReceiveLoginChallenge(error: String)
}

class BSBaseAuthenticator: NSObject, BSAuthenticator, TimerCallbacks {
    var webClient: BSWebClient
    var account: Account?
    var configurations: Configurations?
    var webClientDelegate: BSWebNavigationDelegate
    var completionHandler: ((Bool, ASLException?) -> Void)?
    var authenticationDelegate: BSAuthenticaorDelegate?
    var listnerAdded = false
    let panelistID = LibContext.shared.authProvider.getPanelistID()
    var scraperListener: ScraperProgressListener?
    var scrapingMode: String?
    
    lazy var timerHandler: TimerHandler = {
        return TimerHandler(timerCallback: self)
    }()
    
    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate, scraperListener: ScraperProgressListener?) {
        self.webClient = webClient
        self.webClientDelegate = delegate
        self.scraperListener = scraperListener
    }
    
    func authenticate(account: Account,
                      configurations: Configurations,
                      scrapingMode: String?,
                      completionHandler: @escaping ((Bool, ASLException?) -> Void)) {
        self.account = account
        self.completionHandler = completionHandler
        self.webClientDelegate.setObserver(observer: self)
        self.webClient.navigationDelegate = webClientDelegate
        self.webClient.loadUrl(url: configurations.login)
        self.configurations = configurations
        self.scrapingMode = scrapingMode
    }
    
    func onPageFinish(url: String) throws {
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        FirebaseAnalyticsUtil.logSentryError(error: error)
        throw error
    }
    func onStartPageNavigation(url: String) {
        print("$$$$ onStartPageNavigation ")
    }
    
    func onFailPageNavigation(for url: String, withError error: Error) {
        FirebaseAnalyticsUtil.logSentryError(error: error)
        print(AppConstants.tag, Strings.ErrorDuringNavigation, error.localizedDescription)
    }
    
    func onNetworkDisconnected() {
        
    }
    
    func onTimerTriggered(action: String) {
       
    }
    
    // All foreground authenticatores should override this method and return true
    func isForegroundAuthentication() -> Bool {
        return false
    }
    
    func showWebClient() {
        let view = webClient.superview
        webClient.isHidden = false
        view?.bringSubviewToFront(webClient)
    }
    
    func hideWebClient() {
        let view = webClient.superview
        webClient.isHidden = true
        view?.bringSubviewToFront(webClient)
    }
}

extension BSBaseAuthenticator: BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?) {
        guard let url = url?.absoluteString else {
            return
        }
        self.timerHandler.stopTimer()
        do {
            try self.onPageFinish(url: url)
        } catch {
            print("failed to call the onPageFinish")
        }
      
    }
    
    func didStartPageNavigation(url: URL?) {
        if let url = url {
            if self.isForegroundAuthentication() {
                if let account = account?.source {
                    if account != OrderSource.Walmart {
                        print("$$$$ didStartPageNavigationcalled in bsBaseAuthenticator",url)
                        self.timerHandler.startTimer(action: Actions.LoadingURl + url.absoluteString)
                    }
                    self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: false)
                }
            }
            //TODO check 
            hideWebClient()
        } else {
            return
        }
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        var logEventAttributes:[String:String] = [:]
        print("$$$$ didStartPageNavigation called in bsBaseAuthenticator",url)
        FirebaseAnalyticsUtil.logSentryMessage(message: "did Fail page navigation \(url)")
        logEventAttributes = [EventConstant.OrderSource: self.account?.source.value ?? "",
                              EventConstant.PanelistID: panelistID,
                              EventConstant.OrderSourceID: self.account?.userID ?? "",
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.EventName: EventType.DidFailPageNavigation,
                              EventConstant.Status: EventStatus.Failure]
        if let url = url {
            if self.isForegroundAuthentication() {
                let source = account?.source
                if source != OrderSource.Walmart {
                    self.timerHandler.stopTimer()
                    self.timerHandler.removeCallbackListener()
                    if listnerAdded {
                        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                    }
                }
            }
            logEventAttributes[EventConstant.URL] = url.absoluteString
            self.onFailPageNavigation(for: url.absoluteString,withError: error)
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        print(AppConstants.tag, Strings.ErrorDuringNavigation, error.localizedDescription)
    }
}
