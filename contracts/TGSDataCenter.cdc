// Owned imports
import "TGSInterfaces"

/// The contract for TGS DataCenter
///
pub contract TGSDataCenter {
    /* --- Canonical Paths --- */
    pub let TGSDataCenterStoragePath: StoragePath

    /* --- Events --- */

    pub event ContractInitialized()

    pub event ThirdPartyMappingUpdated(_ platform: String, _ uid: String, _ address: Address)
    pub event DataCenterPropertyUpdated(_ key: String, _ valueType: String)

    /* --- Interfaces & Resources --- */

    pub resource interface SharedDataCenterPublic {
        pub fun getAddressByThirdpartyUid(_ platform: String, _ uid: String): Address?
    }

    /// Shared data for all TGS users
    ///
    pub resource SharedDataCenter: SharedDataCenterPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter {
        /// A bucket of resources so that the Manager resource can be easily extended with new functionality.
        pub let resources: @{String: AnyResource}
        /// A mapping from property key to property value
        access(contract) let properties: {String: AnyStruct}
        /// A mapping from third-party platform to its user id to TGS user address
        access(self) let thirdPartyMapping: {String: {String: Address}}

        init() {
            self.thirdPartyMapping = {}
            self.properties = {}

            self.resources <- {}
        }

        destroy () {
            destroy <- self.resources
        }

        /* === public implementation === */

        pub fun getAddressByThirdpartyUid(_ platform: String, _ uid: String): Address? {
            if let uids = self.thirdPartyMapping[platform] {
                return uids[uid]
            } else {
                return nil
            }
        }

        /* === private methods === */

        /// For internal settings only
        ///
        access(account) fun setThirdpartyUid(_ platform: String, _ uid: String, _ address: Address) {
            if let uids = self.thirdPartyMapping[platform] {
                uids[uid] = address
            } else {
                self.thirdPartyMapping[platform] = {uid: address}
            }

            emit ThirdPartyMappingUpdated(platform, uid, address)
        }

        /// For admin usage only
        ///
        pub fun setProperty(_ key: String, _ value: AnyStruct) {
            self.setPropertyRaw(key, value)

            emit DataCenterPropertyUpdated(key, value.getType().identifier)
        }

        /// Borrow properties dictionary
        ///
        access(contract) fun borrowProperties(): &{String: AnyStruct} {
            return &self.properties as &{String: AnyStruct}
        }
    }

    /// Return the primary platform key
    ///
    pub fun getPrimaryPlatfromKey(): String {
        let key = "primary_platform_key"
        let dc = self.borrowDataCenter()
        let keyValue = dc.getProperty(key) as! String?
        return keyValue ?? "tgs"
    }

    /// Borrow the data center for external usage
    ///
    pub fun borrowDataCenter(): &{SharedDataCenterPublic, TGSInterfaces.PropertiesHolder} {
        return self.borrowDataCenterInternal()
    }

    /// Borrow the data center for internal usage
    ///
    access(account) fun borrowDataCenterInternal(): &SharedDataCenter {
        return self.account.borrow<&SharedDataCenter>(from: self.TGSDataCenterStoragePath)
            ?? panic("Failed to load data center")
    }

    /// Helper function to get address by third-party uid
    ///
    pub fun getAddressByThirdpartyUid(_ platform: String, _ uid: String): Address? {
        return self.borrowDataCenterInternal().getAddressByThirdpartyUid(platform, uid)
    }

    init() {
        // Data center
        let dataCenterIdentifier = "TGSDataCenter_".concat(self.account.address.toString())
        self.TGSDataCenterStoragePath = StoragePath(identifier: dataCenterIdentifier)!

        let sharedDC <- create SharedDataCenter()
        self.account.save(<- sharedDC, to: self.TGSDataCenterStoragePath)
    }
}
