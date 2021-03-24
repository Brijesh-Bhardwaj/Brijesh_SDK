//
//  LibContext.swift
//  OrderScrapper
//

import Foundation
import Combine

class LibContext {
    private static var instance: LibContext?
    
    private init() {
        
    }
    
    static var shared: LibContext {
        get {
            if LibContext.instance == nil {
                LibContext.instance = LibContext()
            }
            return LibContext.instance!
        }
    }
    
    var authProvider: AuthProvider!
    var viewPresenter: ViewPresenter!
    
    var scrapeCompletionPublisher = PassthroughSubject<Bool, Never>()
    var webAuthErrorPublisher = PassthroughSubject<Bool, Never>()
    var authenticationErrorPublisher = PassthroughSubject<Bool, Never>()
}
