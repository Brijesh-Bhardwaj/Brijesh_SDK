//
//  FetchSuccessView.swift
//  OrderScrapper
//

import UIKit

class FetchSuccessView: UIView {
    let nibName = "FetchSuccessView"
    
    var buttonClickHandler: (() -> Void)?
    var scrapeContinueClickHandler: (() -> Void)?
    var scrapeLaterClickHandler: (() -> Void)?
    var doneButtonClickHandler: (() -> Void)?
    var retryButtonClickHandler: (() -> Void)?
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var fetchSuccessMessage: UILabel!
    
    @IBOutlet weak var fetchView: UIImageView!
    
    @IBOutlet weak var continueButton: UIButton!
    
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var okButton: UIButton!
    
    @IBOutlet weak var incentiveMessage: UILabel!
    
    @IBOutlet weak var retryButton: UIButton!
    
    @IBOutlet weak var doneButton: UIButton!
    
    var fetchSuccess: String {
        get {
            return ""
        }
        set {
            self.fetchSuccessMessage.text = newValue
        }
    }
    
    var imageView: UIImage {
        get {
            return UIImage(named: "")!
        }
        set {
            self.fetchView.image = newValue
        }
    }
    
    var hideOkButton: Bool {
        get {
            return false
        }
        set {
            okButton.isHidden = newValue
        }
    }
    
    var hideContinueButton: Bool {
        get {
            return false
        }
        set {
            continueButton.isHidden = newValue
        }
    }
    
    var hideCancelButton: Bool {
        get {
            return false
        }
        set {
            cancelButton.isHidden = newValue
        }
    }
    
    var successIncentiveMessage: String {
        get {
            return ""
        }
        set {
            self.incentiveMessage.text = newValue
        }
    }
    
    var hideRetryButton: Bool {
        get {
            return false
        }
        set {
            retryButton.isHidden = newValue
        }
    }
    
    var hideDoneButton: Bool {
        get {
            return false
        }
        set {
            doneButton.isHidden = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }
    
    @IBAction func didClickOkButton(_ sender: Any) {
        if let clickHandler = buttonClickHandler {
            clickHandler()
        }
    }
    
    @IBAction func didClickContinueButton(_ sender: Any) {
        if let scrapeContinueClickHandler = scrapeContinueClickHandler {
            scrapeContinueClickHandler()
            print("###### didClickContinueButton")
        }
    }
    
    @IBAction func didClickCancelButton(_ sender: Any) {
        if let scrapeLaterClickHandler = scrapeLaterClickHandler {
            scrapeLaterClickHandler()
            print("###### didClickCancelButton")
        }
    }
    
    @IBAction func didClickDoneButton(_ sender: Any) {
        if let doneButtonClickHandler = doneButtonClickHandler {
            doneButtonClickHandler()
            print("###### didClickDoneButton")
        }
    }
    
    @IBAction func didRetryClickButton(_ sender: Any) {
        if let retryButtonClickHandler = retryButtonClickHandler {
            retryButtonClickHandler()
            print("###### didRetryClickButton")
        }
    }
    
    private func initView() {
        let nib = UINib(nibName: nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        self.addSubview(self.contentView)
    }
}
