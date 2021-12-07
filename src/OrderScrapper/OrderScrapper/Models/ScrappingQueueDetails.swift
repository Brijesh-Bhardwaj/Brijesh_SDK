//
//  ScrappingQueueDetails.swift
//  OrderScrapper
//
//  Created by Amey Ranade on 27/09/21.
//

import Foundation


public class ScrapingAccountInfo: Equatable {
    
    var account: Account
    var orderExtractionListner: OrderExtractionListener
    var source: FetchRequestSource
    
    
    init(account: Account, orderExtractionListner: OrderExtractionListener, source: FetchRequestSource)  {
        self.account = account
        self.orderExtractionListner = orderExtractionListner
        self.source = source
    }
    
    public static func == (lhs: ScrapingAccountInfo, rhs: ScrapingAccountInfo) -> Bool {
        print("!!! isEquals")
       return lhs.account.userID == rhs.account.userID &&
              lhs.account.source == rhs.account.source
    }
    
}
