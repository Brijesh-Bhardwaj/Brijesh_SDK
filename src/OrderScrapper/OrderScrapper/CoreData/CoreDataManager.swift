//
//  CoreDataManager.swift
//  OrderScrapper


import Foundation
import CoreData

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
    public func addAccount(userId: String, password: String, accountStatus: Int16, orderSource: Int16){
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        fetchRequest.predicate = NSPredicate(format: "\(AppConstants.userAccountColumnUserId) = %@", userId)
        
        var account: UserAccountMO?
        do {
            let accounts = try context.fetch(fetchRequest)
            if accounts.count > 0 {
                account = accounts[0] as UserAccountMO
            } else {
                account = NSEntityDescription.insertNewObject(forEntityName: AppConstants.entityName, into: context) as? UserAccountMO
            }
        } catch let error {
            debugPrint("Failed to fetch account: \(error.localizedDescription)")
        }
        if let account = account {
            account.userId = userId
            account.password  = password
            account.accountStatus = accountStatus
            account.orderSource = orderSource
            do {
                try context.save()
            } catch let error {
                print("Failed to add account: \(error.localizedDescription)")
            }
        }
    }
    
    /*
     * fetch user accounts by OrderSource type
     */
    public func fetch(orderSource: OrderSource?)->[UserAccountMO] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        if let orderSource = orderSource {
            fetchRequest.predicate = NSPredicate(format: "\(AppConstants.userAccountColumnOrderSource) == \(orderSource.rawValue)")
        }
        var accounts = [UserAccountMO]()
        do {
            accounts = try context.fetch(fetchRequest)
        } catch let fetchErr {
            print("Failed to fetch Account:",fetchErr)
        }
        return accounts
    }
    
    /*
     * Update user account status using userId
     */
    public func updateUserAccount(userId: String, accountStatus: Int16) throws {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserAccountMO>(entityName: AppConstants.entityName)
        fetchRequest.predicate = NSPredicate(format: "\(AppConstants.userAccountColumnUserId) = %@", userId)
        let accounts = try context.fetch(fetchRequest)
        if accounts.count > 0 {
            let objectUpdate = accounts[0] as NSManagedObject
            
            objectUpdate.setValue(accountStatus, forKey: AppConstants.userAccountColumnAccountStatus)
            try context.save()
        }
    }
    
    public func createNewAccount() -> UserAccountMO {
        let context = persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: AppConstants.entityName, in: context)!
        
        return NSManagedObject(entity: entity, insertInto: nil) as! UserAccountMO
    }
}
