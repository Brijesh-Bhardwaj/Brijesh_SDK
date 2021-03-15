//
//  AmazonNavigationHelper.swift
//  OrderScrapper
//

import Foundation

struct AmazonURL {
    static let signIn           =   "ap/signin"
    static let authApproval     =   "ap/cvf/approval"
    static let twoFactorAuth    =   "ap/mfa"
    static let downloadReport   =   "download-report"
    static let reportID         =   "reportId"
    static let generateReport   =   "gp/b2b/reports/"
}

class AmazonNavigationHelper: NavigationHelper {
    
    func navigationActionForURL(url: URL?) -> NavigationAction {
        guard let url = url else { return .none }
        
        var action: NavigationAction = .none
        
        let urlString = url.absoluteString
        
        if (urlString.contains(AmazonURL.signIn)) {
            action = .authenticate
        } else if (urlString.contains(AmazonURL.authApproval)) {
            action = .approveAuth
        } else if (urlString.contains(AmazonURL.twoFactorAuth)) {
            action = .twoFactorAuth
        } else if (urlString.contains(AmazonURL.downloadReport)
                    && urlString.contains(AmazonURL.reportID)) {
            action = .downloadReport
        } else if (urlString.contains(AmazonURL.generateReport)) {
            action = .generateReport
        }
        return action
    }
}
