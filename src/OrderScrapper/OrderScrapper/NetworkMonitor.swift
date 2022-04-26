//
//  NetworkMonitor.swift
//  OrderScrapper
//

import Foundation
import Network

enum NetworkStatus {
    case connected, disconnected
}

protocol NetworkChangeListener {
    func onNetworkChange(status: NetworkStatus)
}

final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Monitor")
    private var path: NWPath?
    
    private var listener: NetworkChangeListener?
    
    var status: NetworkStatus = .connected
    
    init(listener: NetworkChangeListener) {
        self.listener = listener
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.path = path
            // Monitor runs on a background thread so we need to publish
            // on the main thread
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self.status != .connected {
                        self.status = .connected
                        self.listener?.onNetworkChange(status: self.status)
                    }
                } else {
                    if self.status != .disconnected {
                        self.status = .disconnected
                        self.listener?.onNetworkChange(status: self.status)
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    public func removeListener() {
        self.listener = nil
    }
    
    func hasNetwork() -> Bool {
        if let path = self.path {
            if path.status == NWPath.Status.satisfied {
                return true
            }
        }
        return false
    }
}
