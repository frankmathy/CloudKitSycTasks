//
//  LocalSettings.swift
//  CloudKitSycTasks
//
//  Created by Frank Mathy on 10.03.18.
//  Copyright © 2018 Frank Mathy. All rights reserved.
//

import Foundation
import CloudKit

class LocalSettings {
    
    static let sharedInstance = LocalSettings()
    
    let keyCreatedCustomZone = "CreatedCustomZone"
    let keySubscribedToPrivateChanges = "SubscribedToPrivateChanges"
    let keySubscribedToSharedChanges = "SubscribedToSharedChanges"
    let keyChangeToken = "ChangeToken"

    var defaults = UserDefaults.standard
    
    var createdCustomZone : Bool {
        get {
            return defaults.bool(forKey: keyCreatedCustomZone)
        }
        
        set (value) {
            defaults.set(value, forKey: keyCreatedCustomZone)
        }
    }

    var subscribedToPrivateChanges : Bool {
        get {
            return defaults.bool(forKey: keySubscribedToPrivateChanges)
        }
        
        set (value) {
            defaults.set(value, forKey: keySubscribedToPrivateChanges)
        }
    }

    var subscribedToSharedChanges : Bool {
        get {
            return defaults.bool(forKey: keySubscribedToSharedChanges)
        }
        
        set (value) {
            defaults.set(value, forKey: keySubscribedToSharedChanges)
        }
    }
    
    func getChangeToken(forKey: String) -> CKServerChangeToken? {
        guard let data = defaults.value(forKey: forKey) as? Data else {
            return nil
        }
        guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
            return nil
        }
        print("Read change token for \(forKey): ", token)
        return token
    }
    
    func setChangeToken(forKey: String, newValue : CKServerChangeToken?) {
        if let token = newValue {
            print("Write change token for \(forKey): ", newValue)
            let data = NSKeyedArchiver.archivedData(withRootObject: token)
            defaults.set(data, forKey: forKey)
        } else {
            defaults.removeObject(forKey: forKey)
        }
    }
}
