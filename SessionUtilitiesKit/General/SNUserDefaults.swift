import Foundation

public enum SNUserDefaults {
    
    public enum Bool : Swift.String {
        case hasLaunchedOnce
        case hasSeenGIFMetadataWarning
        case hasSyncedConfiguration
        case hasViewedSeed
        case isUsingFullAPNs
        case isMigratingToV2KeyPair
        case isUsingMultiDevice
    }

    public enum Date : Swift.String {
        case lastProfilePictureUpload
        case lastKeyPairMigrationNudge
        case lastConfigurationSync
    }

    public enum Double : Swift.String {
        case lastDeviceTokenUpload = "lastDeviceTokenUploadTime"
    }

    public enum Int: Swift.String {
        case appMode
    }
    
    public enum String : Swift.String {
        case deviceToken
        /// Just used for migration purposes.
        case displayName
    }
}

public extension UserDefaults {
    
    subscript(bool: SNUserDefaults.Bool) -> Bool {
        get { return self.bool(forKey: bool.rawValue) }
        set { set(newValue, forKey: bool.rawValue) }
    }

    subscript(date: SNUserDefaults.Date) -> Date? {
        get { return self.object(forKey: date.rawValue) as? Date }
        set { set(newValue, forKey: date.rawValue) }
    }
    
    subscript(double: SNUserDefaults.Double) -> Double {
        get { return self.double(forKey: double.rawValue) }
        set { set(newValue, forKey: double.rawValue) }
    }

    subscript(int: SNUserDefaults.Int) -> Int {
        get { return self.integer(forKey: int.rawValue) }
        set { set(newValue, forKey: int.rawValue) }
    }
    
    subscript(string: SNUserDefaults.String) -> String? {
        get { return self.string(forKey: string.rawValue) }
        set { set(newValue, forKey: string.rawValue) }
    }
}
