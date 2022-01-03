//
//  KrogerSubsidiaryAccountVC.swift
//  OrderScrapper


import Foundation
import UIKit
import WebKit

class KrogerSubsidiaryAccountVC: UIViewController{
    
    @IBOutlet var webView: WKWebView!

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    override func viewDidLoad(){
        super.viewDidLoad()
        activityIndicator.startAnimating()
       
        _ = AmazonService.getKrogerSusidiary() { krogerSubsidiaries, error in
            if let krogerSubsidiaries = krogerSubsidiaries {
                if let htmlString = krogerSubsidiaries.htmlResponse {
                    self.activityIndicator.stopAnimating()
                    DispatchQueue.main.async {
                        self.webView.loadHTMLString(htmlString, baseURL: nil)
                    }
                } else {
                    self.activityIndicator.stopAnimating()
                    DispatchQueue.main.async {
                        self.webView.loadHTMLString(Strings.ErrorOnSubsidiaryListAPI, baseURL: nil)
                    }
                    print("Data Not Found")
                }
            } else {
                self.activityIndicator.stopAnimating()
                DispatchQueue.main.async {
                    self.webView.loadHTMLString(Strings.ErrorOnSubsidiaryListAPI, baseURL: nil)
                }
                print("Data Not Found")
            }
        }
    }
    
    @IBAction func didTapBackButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
