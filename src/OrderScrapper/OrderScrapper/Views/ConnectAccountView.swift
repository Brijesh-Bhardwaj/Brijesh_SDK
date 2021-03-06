//
//  ConnectAccountView.swift
//  OrderScrapper
//

import Foundation
import UIKit

protocol ConnectAccountViewDelegate {
    func didTapBackButton()
    func didTapRetryOnError()
    func didTapRetryOnNetworkError()
    func didTapSuccessButton()
    func didTapCancelScraping()
    func didTapContinueScraping()
    func didTapScrapeLater()
    func didTapTryAgain()
    func didTapDone()
}

class ConnectAccountView: UIView {
    private static let nibName = "ConnectAccountView"

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var connectAccountTitle: UILabel!
    @IBOutlet weak var exceptionView: ErrorView!
    @IBOutlet weak var networkErrorView: NetworkErrorView!
    @IBOutlet weak var successView: FetchSuccessView!
    @IBOutlet weak var progressView: ProgressView!
    
    @IBOutlet weak var onlineSuccessView: OnlineSuccessView!
    var delegate: ConnectAccountViewDelegate?
    
    var headerText: String {
        get {
            return ""
        }
        set {
            self.progressView.headerLabel.text = newValue
        }
    }
    
    var stepText: String {
        get {
            return ""
        }
        set {
            self.progressView.stepLabel.text = newValue
        }
    }
    
    var progress: CGFloat {
        get {
            return 0
        }
        set {
            self.progressView.progressView.progress = newValue
        }
    }
    
    var fetchSuccess: String {
        get {
            return ""
        }
        set {
            self.successView.fetchSuccessMessage.text = newValue
        }
    }
    
    var successIncentiveMessage: String {
        get {
            return ""
        }
        set {
            self.successView.incentiveMessage.text = newValue
        }
    }
    
    var statusImage: UIImage {
        get {
            return UIImage(named: "")!
        }
        set {
            self.successView.fetchView.image = newValue
        }
    }
    
    var scrapePercentage: String {
        get {
            return ""
        }
        set {
            self.progressView.scrapePercentage.text = newValue
        }
    }
    
    var hideCancelScrapeBtn: Bool {
        get {
            false
        }
        set {
            self.progressView.cancelScrapeBtn.isHidden = newValue
        }
    }
    
    var successHeaderMessage: String {
        get {
            return ""
        }
        set {
            self.onlineSuccessView.successHeader.text = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
        setupButtonTapHandlers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
        setupButtonTapHandlers()
    }
    
    @IBAction func didTapBackButton(_ sender: Any) {
        self.delegate?.didTapBackButton()
    }
    
    private func initView() {
        let nib = UINib(nibName: ConnectAccountView.nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        self.addSubview(self.contentView)
    }
    
    func setupButtonTapHandlers() {
        self.exceptionView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapRetryOnError()
        }
        
        self.networkErrorView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapRetryOnNetworkError()
        }
        
        self.successView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapSuccessButton()
        }
        
        self.progressView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapCancelScraping()
        }
        
        self.successView.scrapeContinueClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapContinueScraping()
            print("######## continue")
        }
        
        self.successView.scrapeLaterClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapScrapeLater()
            print("######## scrapeLater")
        }
        
        self.successView.retryButtonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapTryAgain()
        }
        
        self.successView.doneButtonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapDone()
        }
        
        self.onlineSuccessView.buttonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapSuccessButton()
        }
    }
    
    override func bringSubviewToFront(_ view: UIView) {
        self.containerView.bringSubviewToFront(view)
    }
}
