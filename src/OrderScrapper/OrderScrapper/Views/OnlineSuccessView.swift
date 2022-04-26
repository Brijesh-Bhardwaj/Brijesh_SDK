//  OnlineSuccessView.swift
//  OrderScrapper


import Foundation

import UIKit

class OnlineSuccessView: UIView {
    let nibName = "OnlineSuccessView"
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var successMessage: UILabel!
    @IBOutlet weak var successNoteMessage: UILabel!
    @IBOutlet weak var okButton: UIButton!
    
    @IBOutlet weak var completeButton: UILabel!
    @IBOutlet weak var successHeader: UILabel!
    var buttonClickHandler: (() -> Void)?
    
    var onlineSuccessMessage: String {
        get {
            return ""
        }
        set {
            self.successMessage.text = newValue
        }
    }
    
    var onlinesuccessNoteMessage: String {
        get {
            return ""
        }
        set {
            self.successNoteMessage.text = newValue
        }
    }
    
    var successHeaderText: String {
        get {
            return ""
        }
        set {
            self.successHeader.text = newValue
        }
    }
    
    @IBAction func didClickOkButton(_ sender: Any) {
        if let clickHandler = buttonClickHandler {
            clickHandler()
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
