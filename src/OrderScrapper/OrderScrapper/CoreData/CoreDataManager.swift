//  CoreDataManager.swift
//  OrderScrapper

import Foundation
import CoreData
import Sentry

class CoreDataManager {
    private static var instance: CoreDataManager!
    
    static let shared: CoreDataManager = {
        if instance == nil {
            instance = CoreDataManager()
        }
        return instance
    }()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let messageKitBundle = Bundle(identifier: AppConstants.identifier)
        let modelURL = messageKitBundle!.url(forResource: AppConstants.resource, withExtension: AppConstants.extensionName)!
        let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
        
        let container = NSPersistentContainer(name: AppConstants.resource, managedObjectModel: managedObjectModel!)
        container.loadPersistentStores { (storeDescription, error) in
            
            if let err = error {
                fatalError("Loading of store failed:\(err)")
            }
        }
        return container
    }()
    /*
     * Add account details into the UserAccount table
     */
    public func addAccount(userId: String, password: String, accountStatus: String, orderSource: Int16, panelistId: String) {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        let userIdPredicate = NSPredicate(format: "\(AppConstants.userAccountColumnUserId) = %@", userId)
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.userAcccountColumnPanelistId) = %@", panelistId)
        
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [userIdPredicate, panelistIdPredicate])
        var account: UserAccountMO?
        do {
            let accounts = try context.fetch(fetchRequest)
            if accounts.count > 0 {
                account = accounts[0] as UserAccountMO
            } else {
                account = NSEntityDescription.insertNewObject(forEntityName: AppConstants.entityName, into: context) as? UserAccountMO
            }
        } catch let error {
            print(AppConstants.tag, "addAccount", error.localizedDescription)
            SentrySDK.capture(error: error)
        }
        if let account = account {
            account.userId = userId
            account.password  = password
            account.accountStatus = accountStatus
            account.orderSource = orderSource
            account.panelistId = panelistId
            do {
                try context.save()
            } catch let error {
                print(AppConstants.tag, "addAccount", error.localizedDescription)
                SentrySDK.capture(error: error)
            }
        }
    }
    
    /*
     * fetch user accounts by OrderSource type
     */
    public func fetch(orderSource: OrderSource?, panelistId: String)->[UserAccountMO] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        var predicates:[NSPredicate] = [NSPredicate]()
        if let orderSource = orderSource {
            let orderSourcePredicate = NSPredicate(format: "\(AppConstants.userAccountColumnOrderSource) == \(orderSource.rawValue)")
            predicates.append(orderSourcePredicate)
        }
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.userAcccountColumnPanelistId) == %@", panelistId)
        predicates.append(panelistIdPredicate)
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: predicates)
        
        var accounts = [UserAccountMO]()
        do {
            accounts = try context.fetch(fetchRequest)
        } catch let fetchErr {
            print("Failed to fetch Account:",fetchErr)
            SentrySDK.capture(message:AppConstants.fetchAccounts)
            SentrySDK.capture(error: fetchErr)
        }
        return accounts
    }
    
    /*
     * Update user account status using userId
     */
    public func updateUserAccount(userId: String, accountStatus: String, panelistId: String) throws {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        
        let userIdPredicate = NSPredicate(format: "\(AppConstants.userAccountColumnUserId) = %@", userId)
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.userAcccountColumnPanelistId) = %@", panelistId)
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [userIdPredicate, panelistIdPredicate])
        
        let accounts = try context.fetch(fetchRequest)
        if accounts.count > 0 {
            let objectUpdate = accounts[0] as NSManagedObject
            
            objectUpdate.setValue(accountStatus, forKey: AppConstants.userAccountColumnAccountStatus)
            try context.save()
        }
    }
    
    public func deleteAccounts(userId: String, panelistId: String) {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: AppConstants.entityName)
        
        let userIdPredicate = NSPredicate(format: "\(AppConstants.userAccountColumnUserId) = %@", userId)
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.userAcccountColumnPanelistId) = %@", panelistId)
        
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [userIdPredicate, panelistIdPredicate])
        let result = try? context.fetch(fetchRequest)
        let resultData = result as! [UserAccountMO]
        
        for object in resultData {
            context.delete(object)
        }
        do {
            try context.save()
        } catch let error as NSError  {
            print(error.userInfo)
            SentrySDK.capture(error: error)
        }
        
    }
    
    public func deleteAccountsByPanelistId(panelistId: String) {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: AppConstants.entityName)
        
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.userAcccountColumnPanelistId) = %@", panelistId)
        
        fetchRequest.predicate = panelistIdPredicate
        let result = try? context.fetch(fetchRequest)
        let resultData = result as! [UserAccountMO]
        
        for object in resultData {
            context.delete(object)
        }
        do {
            try context.save()
        } catch let error as NSError  {
            print(error.userInfo)
            SentrySDK.capture(error: error)
        }
        
    }
    public func createNewAccount() -> UserAccountMO {
        let context = persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: AppConstants.entityName, in: context)!
        
        return NSManagedObject(entity: entity, insertInto: nil) as! UserAccountMO
    }
    
    public func insertOrderDetails(orderDetails: [OrderDetails], completionHandler: @escaping (Bool) -> Void) {
        let context = persistentContainer.viewContext
        context.perform {
            for orderData in orderDetails {
                let orderDetail = NSEntityDescription.insertNewObject(forEntityName: AppConstants.orderDetailEntity, into: context) as! OrderDetailsMO
                orderDetail.orderID = orderData.orderId
                orderDetail.orderDate = orderData.date
                orderDetail.orderSource = orderData.orderSource!
                orderDetail.userID = orderData.userID!
                orderDetail.panelistID = orderData.panelistID!
                orderDetail.orderDetailsURL = orderData.detailsUrl
                orderDetail.startDate = orderData.startDate!
                orderDetail.endDate = orderData.endDate!
                
                do {
                    try context.save()
                } catch let error {
                    print(AppConstants.tag, "addOrderDetails", error.localizedDescription)
                    SentrySDK.capture(error: error)
                }
            }
            completionHandler(true)
        }
    }
    
    public func fetchOrderDetails(orderSource: String, panelistID: String, userID: String) -> [OrderDetailsMO] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<OrderDetailsMO>(entityName: AppConstants.orderDetailEntity)
        
        let orderSourcePredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderSource) == %@", orderSource)
        let panelistIdPredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnPanelistID) == %@", panelistID)
        let orderSourceIDPredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderUserID) == %@", userID)
        
        let sortedOrderDate = NSSortDescriptor(key: "orderDate", ascending: true)
        fetchRequest.sortDescriptors = [sortedOrderDate]
        
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [orderSourcePredicate, panelistIdPredicate, orderSourceIDPredicate])
        
        var orderDetails = [OrderDetailsMO]()
        do {
            orderDetails = try context.fetch(fetchRequest)
        } catch let error {
            print("Failed to fetch orderDetails",error)
            SentrySDK.capture(message: AppConstants.fetchOrderDetails)
            SentrySDK.capture(error: error)
        }
        return orderDetails
    }
    
    public func deleteOrderDetails(userID: String, panelistID: String, orderSource: String) {
        let context = persistentContainer.viewContext
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: AppConstants.orderDetailEntity)
            
            let userIDPredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderUserID) = %@", userID)
            let panelistIdPredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnPanelistID) = %@", panelistID)
            let orderSourcePredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderSource) = %@", orderSource)
            
            fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [userIDPredicate, panelistIdPredicate, orderSourcePredicate])
            let results = try? context.fetch(fetchRequest)
            let resultData = results as! [OrderDetailsMO]
            
            for orderData in resultData {
                context.delete(orderData)
            }
            do {
                try context.save()
            } catch let error {
                print("Failed to save orderDetails",error)
                SentrySDK.capture(error: error)
            }
        }
    }
    
    public func deleteOrderDetailsByOrderID(orderID: String, orderSource: String) {
        let context = persistentContainer.viewContext
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: AppConstants.orderDetailEntity)
            
            let orderIDPredicate =  NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderID) = %@", orderID)
            let orderSourcePredicate = NSPredicate(format: "\(AppConstants.orderDetailsColumnOrderSource) = %@", orderSource)
            
            fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [orderIDPredicate,  orderSourcePredicate])
            let result = try? context.fetch(fetchRequest)
            let resultData = result as! [OrderDetailsMO]
            for orderDetails in resultData {
                context.delete(orderDetails)
            }
            do {
                try context.save()
            } catch let error as NSError  {
                print(error.userInfo)
                SentrySDK.capture(error: error)
            }
        }
    }
    
    public func addJSUrls(urls: [String]) {
        
    }
    
    public func getJSUrls() -> [String] {
        
        return []
    }
}
