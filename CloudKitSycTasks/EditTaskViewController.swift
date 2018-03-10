//
//  EditTaskViewController.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//

import UIKit

class EditTaskViewController: UIViewController {
    
    var task : Task?

    @IBOutlet weak var taskDescriptionField: UITextField!
    @IBOutlet weak var taskCompletedSwitch: UISwitch!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if task != nil {
            taskDescriptionField.text = task?.taskName
            taskCompletedSwitch.isOn = (task?.done)!
            updateSaveButtonState()
        }
    }
    
    @IBAction func onDescriptiontChanged(_ sender: UITextField) {
        task?.taskName = taskDescriptionField.text
        updateSaveButtonState()
    }
    
    @IBAction func completedSwitchChanged(_ sender: UISwitch) {
        task?.done = taskCompletedSwitch.isOn
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = taskDescriptionField.text!.count > 0
    }
}
