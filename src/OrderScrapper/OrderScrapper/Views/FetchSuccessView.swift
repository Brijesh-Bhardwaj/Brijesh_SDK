//
//  FetchSuccessView.swift
//  OrderScrapper
//

import UIKit

class FetchSuccessView: UIView {
    let nibName = "FetchSuccessView"
    
    var buttonClickHandler: (() -> Void)?
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var fetchSuccessMessage: UILabel!
    
    var fetchSuccess: String {
        get {
            return ""
        }
        set {
            self.fetchSuccessMessage.text = newValue
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
    
    private func initView() {
        let nib = UINib(nibName: nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        self.addSubview(self.contentView)
    }
}
