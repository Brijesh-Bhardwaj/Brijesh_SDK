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
    
    func addData(data: Dictionary<String, Any>, orderDetail: OrderDetails, orderState: String) {
        if !data.isEmpty {
            let uploadOperation = DataUploadOperation()
            uploadOperation.orderId = String(orderDetail.orderId)
            uploadOperation.panelistId = String(orderDetail.panelistID!)
            uploadOperation.userId = String(orderDetail.userID!)
            uploadOperation.orderSource = String(orderDetail.orderSource!)
            uploadOperation.data = data
            uploadOperation.dateRange = DateRange(fromDate: orderDetail.startDate, toDate: orderDetail.endDate, enableScraping: true, lastOrderId: nil, scrappingType: nil, showNotification: false)
            uploadOperation.orderState = orderState
            uploadOperation.orderSectionType = String(orderDetail.orderSectionType!)
            uploadOperation.uploadRetryCount = orderDetail.uploadRetryCount
            
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
    var orderState: String?
    var orderSectionType: String?
    var uploadRetryCount: Int16?
    
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
            let orderRequest = OrderRequest(panelistId: self.panelistId, platformId: self.userId, fromDate: dateRange.fromDate!, toDate: dateRange.toDate!, status: self.orderState!, data: [data])
            if orderSource == OrderSource.Instacart.value || orderSource == OrderSource.Walmart.value {
                if self.orderState == OrderState.Completed.rawValue {
                   if self.orderSource == OrderSource.Instacart.value {
                    let orderState = Utils.getKeyForOrderState(orderSource: .Instacart)
                    UserDefaults.standard.setValue(AppConstants.Completed, forKey: orderState)
                   } else {
                    let orderState = Utils.getKeyForOrderState(orderSource: .Walmart)
                    UserDefaults.standard.setValue(AppConstants.Completed, forKey: orderState)
                   }
                }
            }
            _ = AmazonService.uploadOrderHistory(orderRequest: orderRequest, orderSource: self.orderSource) { [self] response, error in
                DispatchQueue.global().async {
                    var logEventAttributes:[String:String] = [:]

                    logEventAttributes = [EventConstant.OrderSource:self.orderSource,
                                          EventConstant.PanelistID: self.panelistId,
                                          EventConstant.OrderSourceID: self.userId]
                    
                    if let response = response {
                        print("### uploadData() Response ", response)
                        CoreDataManager.shared.deleteOrderDetailsByOrderID(orderID: self.orderId,
                                                                           orderSource: self.orderSource)
                    } else {
                        self.updateUploadRetryCount()
                        logEventAttributes[EventConstant.Status] = EventStatus.Failure
                        if let error = error {
                            logEventAttributes[EventConstant.EventName] = EventType.UploadOrdersAPIFailed
                            FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                        } else {
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.UploadOrdersAPIFailed, eventAttributes: logEventAttributes)
                        }
                    }
                    
                    finish()
                }
            }
        }
    }
    
    public func finish() {
        state = .finished
    }
    
    func updateUploadRetryCount() {
        var uploadRetryCount = self.uploadRetryCount ?? 0
        print("$$$$ orderRetryCount failed",uploadRetryCount)
        uploadRetryCount = uploadRetryCount + 1
        if let userId = self.userId, let panelistId = self.panelistId {
            do {
                try CoreDataManager.shared.updateRetryCountInOrderDetails(userId: userId, panelistId: panelistId, orderSource: self.orderSource, orderId: self.orderId, retryCount: uploadRetryCount)
            } catch let error {
                print(AppConstants.tag, "updateOrderDetailsWithExceptionState", error.localizedDescription)
                let logEventAttributes:[String:String] = [EventConstant.PanelistID: panelistId,
                                                          EventConstant.OrderSourceID: userId,
                                                          EventConstant.OrderSource: self.orderSource,
                                                          EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
            }
        }
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
