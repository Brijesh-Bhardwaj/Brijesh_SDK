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
            return 0
        }
        set {
            progressView.progress = newValue
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
}
