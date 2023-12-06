// Third-party imports
import "MetadataViews"
import "HybridCustody"

// Owned imports
import "TGSLogging"
import "TGSComponent"

/// General Inteface contract for TGS
///
pub contract TGSInterfaces {

    /// The public interface for a resource with properties
    ///
    pub resource interface PropertiesHolder {
        /// Return the property keys
        ///
        pub fun getPropertyKeys(): [String] {
            let properties = self.borrowProperties()
            return properties.keys
        }

        /// Return the property value for the given key
        ///
        pub fun getProperty(_ key: String): AnyStruct? {
            let properties = self.borrowProperties()
            return properties[key]
        }

        /// Borrow properties dictionary
        ///
        access(contract) fun borrowProperties(): &{String: AnyStruct}
    }

    /// The private interface for a resource with properties
    ///
    pub resource interface PropertiesSetter {
        /// Set property
        /// **Please override this method**
        ///
        pub fun setProperty(_ key: String, _ value: AnyStruct) {
            self.setPropertyRaw(key, value)
        }

        /// The raw method for property setting
        ///
        pub fun setPropertyRaw(_ key: String, _ value: AnyStruct) {
            let properties = self.borrowProperties()
            properties[key] = value
        }

        /// Borrow properties dictionary
        ///
        access(contract) fun borrowProperties(): &{String: AnyStruct}
    }

    /// The private interface for a resource with properties and Display
    ///
    pub resource interface DisplayProperties {
        /// Set the name of this resource
        ///
        pub fun setName(_ name: String) {
            self.setPropertyInternal("_internal:name", name)
        }

        /// Set the description of this resource
        ///
        pub fun setDesctiption(_ description: String) {
            self.setPropertyInternal("_internal:description", description)
        }

        /// Set the image of this resource
        ///
        pub fun setImage(_ image: String) {
            self.setPropertyInternal("_internal:image", image)
        }

        /// Get the name of this resource
        ///
        pub fun getName(): String {
            return self.getPropertyInternal("_internal:name") as! String
        }

        /// Get the description of this resource
        ///
        pub fun getDescription(): String {
            return self.getPropertyInternal("_internal:description") as! String
        }

        /// Get the image url of this resource
        ///
        pub fun getImage(): String {
            return self.getPropertyInternal("_internal:image") as! String
        }

        /// Set the property by key
        ///
        access(contract) fun setPropertyInternal(_ key: String, _ value: AnyStruct)

        /// Return the property value for the given key
        ///
        access(contract) fun getPropertyInternal(_ key: String): AnyStruct?
    }

    /// The interface for a resource to access the account manager
    ///
    pub resource interface AccountManagerAccessor {
        /// Returns the account manager capability
        ///
        pub fun getAccountManager(): Capability<&HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}>
    }

    /// The struct for storage data info
    ///
    pub struct ResourceStorageInfo {
        /// Path in storage where this resource is recommended to be stored.
        pub let storagePath: StoragePath
        /// Public path which must be published to expose public capabilities of this resource
        pub let publicPath: PublicPath
        /// Public capability can be used by other resources
        pub let publicCapabilityType: Type
        /// Private capability can only be used by who has the private capability
        pub let privateCapabilityType: Type

        init(
            storagePath: StoragePath,
            publicPath: PublicPath,
            publicCapabilityType: Type,
            privateCapabilityType: Type
        ) {
            self.storagePath = storagePath
            self.publicPath = publicPath
            self.publicCapabilityType = publicCapabilityType
            self.privateCapabilityType = privateCapabilityType
        }
    }
}
