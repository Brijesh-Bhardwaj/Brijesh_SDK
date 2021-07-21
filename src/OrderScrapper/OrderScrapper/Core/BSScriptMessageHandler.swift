//  BSScriptMessageHandler.swift
//  OrderScrapper

import Foundation
import WebKit

internal protocol ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage)
}

class BSScriptMessageHandler: NSObject {
    private var listener: ScriptMessageListener?
    
    func addScriptMessageListener(listener: ScriptMessageListener) {
        self.listener = listener
    }
    
    func removeScriptMessageListener() {
        self.listener = nil
    }
}

extension BSScriptMessageHandler: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        listener?.onScriptMessageReceive(message: message)
        print("#### userContentController")
    }
}
