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
        saveChanges()
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
        let task = tasks[index]
        cloudKitModel.delete(task: task)
        guard let context = getContext() else { return }
        context.delete(task)
        saveChanges()
    }
    
    
}
