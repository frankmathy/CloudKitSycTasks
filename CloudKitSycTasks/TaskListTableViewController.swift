//
//  TaskListTableViewController.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//

import UIKit
import CoreData

class TaskListTableViewController: UITableViewController {
    
    let model = TaskModel.sharedInstance

    override func viewDidLoad() {
        super.viewDidLoad()
        model.dataChangedHandler = {
            self.model.reload()
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        model.reload()
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.tasks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as? TaskTableViewCell
        let task = model.tasks[indexPath.row]
        cell?.taskDescriptionField.text = task.taskName
        if task.done {
            cell?.statusField.text = "Done"
        } else {
            cell?.statusField.text = "Todo"
        }
        return cell!
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            model.deleteAtIndex(index: indexPath.row)
            model.reload()
            self.tableView.reloadData()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController else {
            fatalError("Unexpected detination: \(segue.destination)")
        }
        guard let editTaskController = navigationController.topViewController as? EditTaskViewController else {
            fatalError("Unexpected detination: \(segue.destination)")
        }
        switch segue.identifier ?? "" {
        case "Add":
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let context = appDelegate.persistentContainer.viewContext
            editTaskController.task = Task(context: context)
        case "Edit":
            guard let selectedCell = sender as? UITableViewCell else {
                fatalError("Unexpected sender: \(sender!)")
            }
            guard let indexPath = tableView.indexPath(for: selectedCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            editTaskController.task = model.tasks[indexPath.row]
        default:
            fatalError("Unexpected Segue Identifier: \(segue.identifier!)")
        }
    }
    
    @IBAction func saveEditTaskViewController(_ segue: UIStoryboardSegue) {
        if let editTaskViewController = segue.source as? EditTaskViewController, let task = editTaskViewController.task {
            model.save(task: task)
            model.reload()
            self.tableView.reloadData()
        }
    }

    @IBAction func cancelEditTaskViewController(_ segue: UIStoryboardSegue) {
    }
    
    @IBAction func shareButtonPressed(_ sender: UIButton) {
        let pointInTable = sender.convert(sender.bounds.origin, to: self.tableView)
        let cellIndexPath = self.tableView.indexPathForRow(at: pointInTable)
        let task = model.tasks[cellIndexPath!.row]
        print("Clicked share button for task: \(task.taskName!)")
    }
    
}

