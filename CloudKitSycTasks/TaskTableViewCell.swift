//
//  TaskTableViewCell.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 18.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//

import UIKit

class TaskTableViewCell: UITableViewCell {
    @IBOutlet weak var taskDescriptionField: UILabel!
    @IBOutlet weak var statusField: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
