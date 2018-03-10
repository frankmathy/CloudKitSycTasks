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
    var tasks = [Task]()
    let cloudKitModel : CloudKitModel? = nil
    
    private func getContext() -> NSManagedObjectContext? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return nil }
        return appDelegate.persistentContainer.viewContext
    }
    
    func reload() {
        guard let context = getContext() else { return }
        let taskFetch = NSFetchRequest<Task>(entityName: "Task")
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
    
    func deleteAtIndex(index : Int) {
        let task = tasks[index]
        guard let context = getContext() else { return }
        context.delete(task)
        saveChanges()
    }
    
    
}
