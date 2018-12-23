//
//  TaskModel.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class TaskModel {
    static let sharedInstance = TaskModel()

    var tasks = [Task]()
    
    let cloudKitModel = CloudKitModel.sharedInstance
    
    var dataChangedHandler : (() -> Void)?
    
    let taskEntityName = "Task"
    
    let cloudKitDeleteTaskEntityName = "CloudKitDeleteTask"
    
    var context : NSManagedObjectContext?
    
    public func getContext() -> NSManagedObjectContext? {
        if context == nil {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return nil }
            context = appDelegate.persistentContainer.viewContext
        }
        return context
    }
    
    func reload() {
        guard let context = getContext() else { return }
        let taskFetch = NSFetchRequest<Task>(entityName: taskEntityName)
        do {
            tasks = try context.fetch(taskFetch)
        } catch let error as NSError {
            print("Error loading tasks: \(error), \(error.userInfo)")
            return
        }
    }
    
    func cancelChanges() {
        guard let context = getContext() else { return }
        context.reset()
    }
    
    func save(task : Task) {
        task.cloudKitDirtyFlag = true
        saveChanges()
        
        // Propagate to CloudKit
        cloudKitModel.save(task: task)
    }
    
    func saveChanges() {
        guard let context = getContext() else { return }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Error savings: \(nserror), \(nserror.userInfo)")
                return
            }
        }
    }
    
    func findTask(cloudKitRecordName : String) -> Task? {
        guard let context = getContext() else { return nil }
        let fetch = NSFetchRequest<Task>(entityName: taskEntityName)
        fetch.predicate = NSPredicate(format: "cloudKitRecordName == %@", cloudKitRecordName)
        do {
            let records = try context.fetch(fetch)
            if records.count > 0 {
                return records.first
            }
        } catch let error as NSError {
            print("Could not load task. \(error), \(error.userInfo)")
        }
        return nil
    }
    
    func deleteAtIndex(index : Int) {
        // Add deletion for CloudKit sync
        guard let context = getContext() else { return }
        let task = tasks[index]
        if task.cloudKitOwnerName != nil && task.cloudKitZoneName != nil && task.cloudKitRecordName != nil {
            let deleteTask = CloudKitDeleteTask(context: context)
            deleteTask.cloudKitOwnerName = task.cloudKitOwnerName!
            deleteTask.cloudKitRecordName = task.cloudKitRecordName!
            deleteTask.cloudKitZoneName = task.cloudKitZoneName!
            deleteTask.cloudKitSharedDB = task.cloudKitSharedDB
        }

        // Delete task
        context.delete(task)
        saveChanges()

        // Propagate to CloudKit
        cloudKitModel.delete(task: task)
    }
    
    func findDirtyTasks() -> [Task]? {
        guard let context = getContext() else { return nil }
        let fetch = NSFetchRequest<Task>(entityName: taskEntityName)
        fetch.predicate = NSPredicate(format: "cloudKitDirtyFlag == YES")
        do {
            let records = try context.fetch(fetch)
            return records
        } catch let error as NSError {
            print("Could not load task. \(error), \(error.userInfo)")
        }
        return nil
    }
    
    func findAllDeletions() -> [CloudKitDeleteTask]? {
        guard let context = getContext() else { return nil }
        let fetch = NSFetchRequest<CloudKitDeleteTask>(entityName: cloudKitDeleteTaskEntityName)
        do {
            let records = try context.fetch(fetch)
            return records
        } catch let error as NSError {
            print("Could not load deletions. \(error), \(error.userInfo)")
        }
        return nil
    }
    
    func deleteDeleteTask(ownerName : String, recordName : String, zoneName : String) {
        guard let context = getContext() else { return }
        let fetch = NSFetchRequest<CloudKitDeleteTask>(entityName: cloudKitDeleteTaskEntityName)
        let ownerPredicate = NSPredicate(format: "cloudKitOwnerName == %@", ownerName)
        let recordNamePredicate = NSPredicate(format: "cloudKitRecordName == %@", recordName)
        let zoneNamePredicate = NSPredicate(format: "cloudKitZoneName == %@", zoneName)
        fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ownerPredicate, recordNamePredicate, zoneNamePredicate])
        do {
            let records = try context.fetch(fetch)
            print("Removing \(records.count) delete tasks for record \(recordName)")
            for record in records {
                context.delete(record)
            }
        } catch let error as NSError {
            print("Could not remove delete tasks for recordName \(recordName): \(error), \(error.userInfo)")
        }
    }
}
