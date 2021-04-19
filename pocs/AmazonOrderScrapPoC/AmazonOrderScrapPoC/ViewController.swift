//
//  ViewController.swift
//  AmazonOrderScrapPoC
//
//  Created by Avinash Mohanta on 23/02/21.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var progressContainer: UIView!
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var showDocButton: UIButton!
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var pwdField: UITextField!
    @IBOutlet weak var registerButton: UIButton!
    
    private var downloadURL: URL?
    
    private let baseURL = "https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=900&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fb2b%2Freports%2F136-9723095-1427523%3Fie%3DUTF8%26%252AVersion%252A%3D1%26%252Aentries%252A%3D0"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        self.showDocButton.isHidden = true
        
        hideProgressView(hide: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else {
            return
        }
        print(url)
        self.progressContainer.isHidden = false
        
        var js = ""
        
        if (url.absoluteString.contains("https://www.amazon.com/ap/signin")) {
            self.progressLabel.text = "Logging In..."
            checkAuthError { (result, error) in
                if let result = result {
                    self.progressLabel.text = result + ". Please check the provided credentials..."
                    self.hideRegisterView(hide: false)
                    self.progressView.isHidden = true
                } else {
                    js = self.injectEmailJS()
                    self.executeJS(javascript: js) { (_, error) in
                        if let _ = error {
                            js = self.injectPasswordJS()
                            self.executeJS(javascript: js) { (_, error) in
                                if let _ = error {
                                    
                                }
                            }
                        }
                    }
                    //check whether to inject email or pwd
                }
            }
        } else if (url.absoluteString.contains("https://www.amazon.com/gp/b2b/reports/")) {
            self.progressLabel.text = "Generating report..."
            js = generateReportJS()
        } else if (url.absoluteString.contains("download-report")
                    && url.absoluteString.contains("reportId")) {
            self.progressLabel.text = "Downloading report..."
            js = downloadReportJS()
        } else if (url.absoluteString.contains("www.amazon.com/ap/cvf/approval")) {
            self.progressLabel.text = "An approval link is sent to your registered number. Please approve it to continue..."
        } else if (url.absoluteString.contains("ap/mfa")) {
            self.progressContainer.isHidden = true
        }
        
        if !js.isEmpty {
            executeJS(javascript: js) { (_, error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func executeJS(javascript: String, completionHandler:((Any?, Error?) -> Void)?) {
        self.webView.evaluateJavaScript(javascript, completionHandler: completionHandler)
    }
    
    func checkAuthError(completionHandler: @escaping (String?, Error?) -> Void) {
        let js = "(function() { var element = document.getElementById('auth-error-message-box');" +
        "if (element != null && element.innerHTML !== null) " +
        "{return element.getElementsByClassName('a-list-item')[0].innerText;} else {" +
        " return ''}})()"
        
        self.webView.evaluateJavaScript(js) { (result, error) in
            if let result = result {
                let strResult = result as! String
                if (strResult.isEmpty) {
                    completionHandler(nil, nil)
                } else {
                    completionHandler(strResult, nil)
                }
                
            } else {
                completionHandler(nil, nil)
            }
        }
    }
    
    func injectEmailJS() -> String {
        let email = self.emailField.text
        if let email = email {
            return "javascript:" +
                "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
        } else {
            return ""
        }
    }
    
    func injectPasswordJS() -> String {
        let password = self.pwdField.text
        if let password = password {
            return "javascript:" +
                "document.getElementById('ap_password').value = '" + password + "';" +
                "document.getElementById('signInSubmit').click()"
        } else {
            return ""
        }
    }
    
    func generateReportJS() -> String {
        let startDay = "1";
        let startMonth = "5";
        let startyear = "2008";
        let endDay = "17";
        let endMonth = "2";
        let endYear = "2021";
        let reportType = "SHIPMENTS";
        
        return "javascript:" +
            "document.getElementById('report-type').value = '" + reportType + "';" +
            "document.getElementById('report-month-start').value = '" + startMonth + "';" +
            "document.getElementById('report-day-start').value = '" + startDay + "';" +
            "document.getElementById('report-year-start').value = '" + startyear + "';" +
            "document.getElementById('report-month-end').value = '" + endMonth + "';" +
            "document.getElementById('report-day-end').value = '" + endDay + "';" +
            "document.getElementById('report-year-end').value = '" + endYear + "';" +
            "document.getElementById('report-confirm').click()"
    }
    
    func downloadReportJS() -> String {
        return "javascript:" +
            "document.getElementById(window['download-cell-'+new URLSearchParams(window.location.search).get(\"reportId\")].id).click()"
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let mimeType = navigationResponse.response.mimeType {
            print("Mime Type:" + mimeType)
            let result = mimeType.compare("text/csv")
            if result == .orderedSame {
                if let url = navigationResponse.response.url {
                    let fileName = getFileNameFromResponse(navigationResponse.response)
                    downloadData(fromURL: url, fileName: fileName) { success, destinationURL in
                        if success, let destinationURL = destinationURL {
                            self.downloadURL = destinationURL
                            DispatchQueue.main.async {
                                self.showDocButton.isHidden = false
                                self.progressView.isHidden = true
                                self.progressLabel.text = "Download Completed..."
                            }
                        }
                    }
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        
        decisionHandler(.allow)
    }
    
    private func getFileNameFromResponse(_ response:URLResponse) -> String {
        if let httpResponse = response as? HTTPURLResponse {
            let headers = httpResponse.allHeaderFields
            if let disposition = headers["Content-Disposition"] as? String {
                let components = disposition.components(separatedBy: ";")
                if components.count > 1 {
                    let innerComponents = components[1].components(separatedBy: "=")
                    if innerComponents.count > 1 {
                        if innerComponents[0].contains("filename") {
                            return innerComponents[1]
                        }
                    }
                }
            }
        }
        return "default.csv"
    }
    
    private func downloadData(fromURL url:URL,
                              fileName:String,
                              completion:@escaping (Bool, URL?) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies() { cookies in
            let session = URLSession.shared
            session.configuration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
            let task = session.downloadTask(with: url) { localURL, urlResponse, error in
                if let localURL = localURL {
                    let destinationURL = self.moveDownloadedFile(url: localURL, fileName: fileName)
                    completion(true, destinationURL)
                }
                else {
                    completion(false, nil)
                }
            }
            
            task.resume()
        }
    }
    
    func fileDownloadedAtURL(url: URL) {
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = self.view
            activityVC.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func moveDownloadedFile(url:URL, fileName:String) -> URL {
        let tempDir = NSTemporaryDirectory()
        let destinationPath = tempDir + fileName
        let destinationURL = URL(fileURLWithPath: destinationPath)
        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.moveItem(at: url, to: destinationURL)
        return destinationURL
    }
    
    private func hideRegisterView(hide: Bool) {
        self.emailField.isHidden = hide
        self.pwdField.isHidden = hide
        self.registerButton.isHidden = hide
    }

    private func hideProgressView(hide: Bool) {
        self.progressView.isHidden = hide
        self.progressLabel.isHidden = hide
    }
    
    @IBAction func showDocument(_ sender: Any) {
        if let downloadURL = self.downloadURL {
            self.fileDownloadedAtURL(url: downloadURL)
        }
    }
    
    @IBAction func register(_ sender: Any) {
        hideRegisterView(hide: true)
        hideProgressView(hide: false)
        
        let email = self.emailField.text
        let pwd = self.pwdField.text
        
        if let email = email, let pwd = pwd {
            if !email.isEmpty && !pwd.isEmpty {
                let url = URL(string: baseURL)!;
                let urlRequest = URLRequest(url: url)
                
                self.webView.load(urlRequest)
                self.progressLabel.text = "Initializing..."
            }
        }
    }
}

