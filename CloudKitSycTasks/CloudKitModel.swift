//
//  CloudKitModel.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//  See: https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/MaintainingaLocalCacheofCloudKitRecords/MaintainingaLocalCacheofCloudKitRecords.html#//apple_ref/doc/uid/TP40014987-CH12-SW1
//

import Foundation
import UIKit
import CloudKit
import CoreData

class CloudKitModel {
    
    static let sharedInstance = CloudKitModel()
    
    let recordNameTask = "Task"
    let columnTaskName = "taskName"
    let columnDone = "done"

    let privateSubscriptionId = "private-changes"
    let sharedSubscriptionId = "shared-changes"
    
    let zoneID = CKRecordZoneID(zoneName: "Todos", ownerName: CKCurrentUserDefaultName)

    let container = CKContainer.default()

    var privateDB : CKDatabase
    var sharedDB : CKDatabase
    
    let reachability = Reachability()!

    init() {
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
        
        let createZoneGroup = DispatchGroup()
        let settings = LocalSettings.sharedInstance
        
        // Create custom zone needed for change tracking functionality
        if !settings.createdCustomZone {
            createZoneGroup.enter()
            let customZone = CKRecordZone(zoneID: zoneID)
            let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [])
            createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
                if (error == nil) {
                    settings.createdCustomZone = true
                } else {
                    print("Error creating custom zone: \(error!)")
                }
                createZoneGroup.leave()
            }
            createZoneOperation.qualityOfService = .userInitiated
            privateDB.add(createZoneOperation)
        }
        
        // Subscribe to change notifications from other devices
        if !settings.subscribedToPrivateChanges {
            let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: privateSubscriptionId)
            createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                if (error == nil) {
                    settings.subscribedToPrivateChanges = true
                } else {
                    print("Error creating subscription to private database: \(error!)")
                }
            }
            privateDB.add(createSubscriptionOperation)
        }
        if !settings.subscribedToSharedChanges {
            let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: sharedSubscriptionId)
            createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                if (error == nil) {
                    settings.subscribedToSharedChanges = true
                } else {
                    print("Error creating subscription to shared database: \(error!)")
                }
            }
            sharedDB.add(createSubscriptionOperation)
        }
        
        // Fetch any changes from the server that happened while the app wasn't running
        createZoneGroup.notify(queue: DispatchQueue.global()) {
            if settings.createdCustomZone {
                self.fetchChanges(in: .private, completion: {
                    if TaskModel.sharedInstance.dataChangedHandler != nil {
                        TaskModel.sharedInstance.dataChangedHandler!()
                    }
                })
                // TODO self.fetchChanges(in: .shared, completion: { })
            }
        }

        setupReachability()
    }
    
    fileprivate func syncLocalChangesToCloudKit() {
        // Save dirty tasks to iCloud
        let tasks = TaskModel.sharedInstance.findDirtyTasks()
        if tasks != nil {
            print("Syncing \(tasks!.count) updates/inserts to CloudKit")
            for task in tasks! {
                self.saveToCloudKit(task: task)
            }
        }
        
        // Delete required tasks to iCloud
        let deletions = TaskModel.sharedInstance.findAllDeletions()
        if deletions != nil {
            print("Syncing \(deletions!.count) deletions to CloudKit")
            for deletion in deletions! {
                self.deleteTask(recordName: deletion.cloudKitRecordName!, zoneName: deletion.cloudKitZoneName!, ownerName: deletion.cloudKitOwnerName!)
            }
        }
    }
    
    func setupReachability() {
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
            
            self.syncLocalChangesToCloudKit()
        }
        reachability.whenUnreachable = { _ in
            print("Not reachable")
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }
    
    func save(task: Task) {
        if reachability.connection != .none {
            saveToCloudKit(task: task)
        }
    }
    
    func saveToCloudKit(task : Task) {
        var record : CKRecord
        if task.cloudKitRecordName != nil && task.cloudKitZoneName != nil && task.cloudKitOwnerName != nil {
            let zoneId = CKRecordZoneID(zoneName: task.cloudKitZoneName!, ownerName: task.cloudKitOwnerName!)
            let recordId = CKRecordID(recordName: task.cloudKitRecordName!, zoneID: zoneId)
            privateDB.fetch(withRecordID: recordId, completionHandler: { (record, error) in
                if let record = record, error == nil {
                    record[self.columnTaskName] = task.taskName as CKRecordValue?
                    record[self.columnDone] = task.done as CKRecordValue
                    self.privateDB.save(record) { (record, error) in
                        guard error == nil else {
                            print("Error saving task to CloudKit:)\(error!)")
                            return
                        }
                        // Flag save success
                        task.cloudKitDirtyFlag = false
                        TaskModel.sharedInstance.saveChanges()
                    }
                }
            })
            record = CKRecord(recordType: recordNameTask, recordID: recordId)
        } else {
            record = CKRecord(recordType: recordNameTask, zoneID: zoneID)
            task.cloudKitRecordName = record.recordID.recordName
            task.cloudKitZoneName = record.recordID.zoneID.zoneName
            task.cloudKitOwnerName = record.recordID.zoneID.ownerName
            record[columnTaskName] = task.taskName as CKRecordValue?
            record[columnDone] = task.done as CKRecordValue
            privateDB.save(record) { (record, error) in
                guard error == nil else {
                    print("Error saving task to CloudKit:)\(error!)")
                    return
                }
                TaskModel.sharedInstance.saveChanges()
            }
        }
    }
    
    fileprivate func deleteTask(recordName : String, zoneName : String, ownerName: String) {
        let recordId = CKRecordID(recordName: recordName, zoneID: CKRecordZoneID(zoneName: zoneName, ownerName: ownerName))
        privateDB.delete(withRecordID: recordId) { (recordId, error) in
            guard error == nil else {
                print("Error deleting task from CloudKit:)\(error!)")
                return
            }
            TaskModel.sharedInstance.deleteDeleteTask(ownerName: ownerName, recordName: recordName, zoneName: zoneName)
        }
    }
    
    func delete(task : Task) {
        if task.cloudKitRecordName != nil && task.cloudKitOwnerName != nil && task.cloudKitZoneName != nil {
            if reachability.connection != .none {
                deleteTask(recordName: task.cloudKitRecordName!, zoneName: task.cloudKitZoneName!, ownerName: task.cloudKitOwnerName!)
            }
        }
    }
    
    func createDatabaseSubscriptionOperation(subscriptionId: String) -> CKModifySubscriptionsOperation {
        let subscription = CKDatabaseSubscription.init(subscriptionID: subscriptionId)
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.qualityOfService = .utility
        return operation
    }
    
    func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
        switch databaseScope {
        case .private:
                fetchDatabaseChanges(database: self.privateDB, databaseTokenKey: "private", completion: completion)
        case .shared:
                fetchDatabaseChanges(database: self.sharedDB, databaseTokenKey: "shared", completion: completion)
        case .public:
                fatalError()
        }
    }
    
    func fetchDatabaseChanges(database: CKDatabase, databaseTokenKey: String, completion: @escaping () -> Void) {
        var changedZoneIDs: [CKRecordZoneID] = []
        
        let changeToken = LocalSettings.sharedInstance.getChangeToken(forKey: databaseTokenKey)
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
        
        operation.recordZoneWithIDChangedBlock = { (zoneID) in
            // The block that processes a single record zone change.
            changedZoneIDs.append(zoneID)
        }
        
        operation.recordZoneWithIDWasDeletedBlock = { (zoneID) in
            // The block that processes a single record zone deletion.
            // TODO Write this zone deletion to memory
        }
        
        operation.changeTokenUpdatedBlock = { (token) in
            // Write this new database change token to memory
            print("Token Updated")
        }
        
        operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
            // The block to execute when the operation completes.
            if let error = error {
                print("Error during fetch shared database changes operation", error)
                completion()
                return
            }
            
            self.fetchZoneChanges(database: database, databaseTokenKey: databaseTokenKey, zoneIDs: changedZoneIDs, completion: {
                // Flush in-memory database change token to disk
                completion()
            })
        }
        
        operation.qualityOfService = .userInitiated
        database.add(operation)
    }
    
    func fetchZoneChanges(database: CKDatabase, databaseTokenKey: String, zoneIDs: [CKRecordZoneID],  completion: @escaping () -> Void) {
        let settings = LocalSettings.sharedInstance

        var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
        for zoneID in zoneIDs {
            let options = CKFetchRecordZoneChangesOptions()
            options.previousServerChangeToken = settings.getChangeToken(forKey: databaseTokenKey)
            optionsByRecordZoneID[zoneID] = options
        }
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: optionsByRecordZoneID)
        
        operation.recordChangedBlock = { (record) in
            // Sync CloudKit record change to local Core Data database
            // The block to execute with the contents of a changed record.
            if record.recordType == self.recordNameTask {
                var task = TaskModel.sharedInstance.findTask(cloudKitRecordName: record.recordID.recordName)
                if task == nil {
                    print("Record creation received: ", record.recordID.recordName)
                    task = Task(context: (TaskModel.sharedInstance.getContext())!)
                    task?.cloudKitRecordName = record.recordID.recordName
                    task?.cloudKitZoneName = record.recordID.zoneID.zoneName
                    task?.cloudKitOwnerName = record.recordID.zoneID.ownerName
                } else {
                    print("Record update received: ", record.recordID.recordName)
                }
                task?.taskName = record[self.columnTaskName] as! String
                task?.done = record[self.columnDone] as! Bool
                task?.cloudKitDirtyFlag = false
                TaskModel.sharedInstance.saveChanges()
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { (recordId, text) in
            // Sync CloudKit deletion to local Core Data database
            print("Record deleted:", recordId)
            let task = TaskModel.sharedInstance.findTask(cloudKitRecordName: recordId.recordName)
            if task != nil {
                TaskModel.sharedInstance.context?.delete(task!)
                TaskModel.sharedInstance.saveChanges()
            }
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            // The block to execute when the change token has been updated.
        }
        
        operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
            // The block to execute when the fetch for a zone has completed.
            print("Zone Change token updated:", changeToken)
            settings.setChangeToken(forKey: databaseTokenKey, newValue: changeToken)
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            // The block to use to process the record zone changes
            if let error = error {
                print("Error fetching zone changes for \(databaseTokenKey) database:", error)
            }
            completion()
        }
        
        database.add(operation)
    }
}
