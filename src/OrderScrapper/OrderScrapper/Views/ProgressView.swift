//
//  ProgressView.swift
//  OrderScrapper
//

import UIKit

class ProgressView: UIView {
    let nibName = "ProgressView"
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var progressView: HorizontalProgressBar!
    @IBOutlet weak var scrapePercentage: UILabel!
    @IBOutlet weak var cancelScrapeBtn: UIButton!
    var buttonClickHandler: (() -> Void)?
    
    var headerText: String {
        get {
            return ""
        }
        set {
            headerLabel.text = newValue
        }
    }
    
    var stepText: String {
        get {
            return ""
        }
        set {
            stepLabel.text = newValue
        }
    }
    
    var progress: CGFloat {
        get {
            return progressView.progress
        }
        set {
            progressView.progress = newValue
        }
    }
    
    var scrapePercentValue: String {
        get {
            return ""
        }
        set {
            scrapePercentage.text = newValue
        }
    }
    
    var hideCancelScrapeBtn: Bool {
        get {
            false
        }
        set {
            cancelScrapeBtn.isHidden = newValue
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
    
    private func initView() {
        let nib = UINib(nibName: nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        self.addSubview(self.contentView)
    }
    
    @IBAction func onCancelClick(_ sender: Any) {
        if let clickHandler = buttonClickHandler {
            clickHandler()
        }
    }
}
