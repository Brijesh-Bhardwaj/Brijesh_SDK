//
//  ErrorView.swift
//  OrderScrapper
//

import UIKit

class ErrorView: UIView {
    let nibName = "ErrorView"
    
    var buttonClickHandler: (() -> Void)?
    
    @IBOutlet var contentView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }
    
    @IBAction func didClickRetryButton(_ sender: Any) {
        if let clickHandler = buttonClickHandler {
            clickHandler()
        }
    }
    
    private func initView() {
        let nib = UINib(nibName: nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        self.addSubview(self.contentView)
    }
}
