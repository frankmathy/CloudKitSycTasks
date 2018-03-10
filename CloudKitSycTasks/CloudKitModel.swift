//
//  CloudKitModel.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//  See: https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/MaintainingaLocalCacheofCloudKitRecords/MaintainingaLocalCacheofCloudKitRecords.html#//apple_ref/doc/uid/TP40014987-CH12-SW1
//

import Foundation
import CloudKit

class CloudKitModel {

    let privateSubscriptionId = "private-changes"
    let sharedSubscriptionId = "shared-changes"
    
    var privateDB : CKDatabase
    var sharedDB : CKDatabase
    
    var taskModel : TaskModel?

    init(taskModel : TaskModel) {
        self.taskModel = taskModel
        
        let container = CKContainer.default()
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
        let zoneID = CKRecordZoneID(zoneName: "Todos", ownerName: CKCurrentUserDefaultName)

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
                self.fetchChanges(in: .private, completion: { })
                self.fetchChanges(in: .shared, completion: { })
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
            // Flush zone deletions for this database to disk
            // Write this new database change token to memory
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
            // The block to execute with the contents of a changed record.
            print("Record changed: ", record)
            // TODO write record change to memory
        }
        
        operation.recordWithIDWasDeletedBlock = { (recordId, tect) in
            // The block to execute with the ID of a record that was deleted.
            print("Record deleted:", recordId)
            // TODO Write this record deletion to memory
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            // The block to execute when the change token has been updated.
            settings.setChangeToken(forKey: databaseTokenKey, newValue: token)
        }
        
        operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
            // The block to execute when the fetch for a zone has completed.
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            // The block to use to process the record zone changes
            if let error = error {
                print("Error fetching zone changes for \(databaseTokenKey) database:", error)
            }
            completion()
        }
    }
}
