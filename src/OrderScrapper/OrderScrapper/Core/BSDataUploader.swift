//  BSDataUploader.swift
//  OrderScrapper

import Foundation
import Sentry

protocol DataUploadListener {
    func onDataUploadComplete()
}
class BSDataUploader {
    private let listener: DataUploadListener
    
    private lazy var operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 2
        
        return operationQueue
    }()
    
    init(listener: DataUploadListener) {
        self.listener = listener
    }
    
    func addData(data: Dictionary<String, Any>, orderDetail: OrderDetails) {
        if !data.isEmpty {
            let uploadOperation = DataUploadOperation()
            uploadOperation.orderId = String(orderDetail.orderId)
            uploadOperation.panelistId = String(orderDetail.panelistID!)
            uploadOperation.userId = String(orderDetail.userID!)
            uploadOperation.orderSource = String(orderDetail.orderSource!)
            uploadOperation.data = data
            uploadOperation.dateRange = DateRange(fromDate: orderDetail.startDate, toDate: orderDetail.endDate, enableScraping: true, lastOrderId: nil)
            
            uploadOperation.completionBlock = { [weak self] in
                guard let self = self else {
                    return
                }
                self.listener.onDataUploadComplete()
            }
            
            operationQueue.addOperation(uploadOperation)
        }
    }
    
    func hasDataForUpload() -> Bool {
        let operationCount = operationQueue.operationCount
        return operationCount > 0
    }
}

class DataUploadOperation: Operation {
    var orderId: String!
    var panelistId: String!
    var userId: String!
    var orderSource: String!
    var data: [String: Any]!
    var dateRange: DateRange!
    
    public override var isAsynchronous: Bool {
        return true
    }
    
    public override var isExecuting: Bool {
        return state == .executing
    }
    
    public override var isFinished: Bool {
        return state == .finished
    }
    
    public override func start() {
        if self.isCancelled {
            state = .finished
        } else {
            state = .ready
            main()
        }
    }
    
    open override func main() {
        if self.isCancelled {
            state = .finished
        } else {
            state = .executing
            let orderRequest = OrderRequest(panelistId: self.panelistId, amazonId: self.userId, fromDate: dateRange.fromDate!, toDate: dateRange.toDate!, data: [data])
            _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest) { [self] response, error in
                DispatchQueue.global().async {
                    if let response = response {
                        print("### uploadData() Response ", response)
                        CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: self.orderId,
                                                                           orderSource: self.orderSource)
                    }
                    if let error = error {
                        SentrySDK.capture(error: error)
                    }
                    
                    finish()
                }
            }
        }
    }
    
    public func finish() {
        state = .finished
    }
    
    // MARK: - State management
    
    public enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }
    
    /// Thread-safe computed state value
    public var state: State {
        get {
            stateQueue.sync {
                return stateStore
            }
        }
        set {
            let oldValue = state
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            stateQueue.sync(flags: .barrier) {
                stateStore = newValue
            }
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    private let stateQueue = DispatchQueue(label: "AsynchronousOperation State Queue", attributes: .concurrent)
    
    /// Non thread-safe state storage, use only with locks
    private var stateStore: State = .ready
}
