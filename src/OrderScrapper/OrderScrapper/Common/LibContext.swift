//
//  LibContext.swift
//  OrderScrapper
//

import Foundation
import Combine

class LibContext {
    private static var instance: LibContext!
    
    private init() {
        
    }
    
    static var shared: LibContext = {
        if instance == nil {
            instance = LibContext()
        }
        return instance
    }()
    
    var authProvider: AuthProvider!
    var viewPresenter: ViewPresenter!
    
    var scrapeCompletionPublisher = PassthroughSubject<(Bool, String?), Never>()
    var webAuthErrorPublisher = PassthroughSubject<Bool, Never>()
    var authenticationErrorPublisher = PassthroughSubject<Bool, Never>()
}
