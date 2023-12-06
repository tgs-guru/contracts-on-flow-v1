// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "TGSAppServiceProfile"
import "TGSVirtualEntity"
import "PropertyShared"
import "PropertyComponent"

/// The contract of PropertyProfile
///
pub contract PropertyProfile: TGSAppServiceProfile {
    /* --- Events --- */

    pub event ProfileCreated(uuid: UInt64, appAddress: Address)

    pub event PublicCapabilityIssued(uuid: UInt64, ownerAddress: Address?)
    pub event PrivateCapabilityIssued(uuid: UInt64, ownerAddress: Address?)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// Public interface of PropertyProfile
    ///
    pub resource interface PropertyProfilePublic {
        pub fun borrowPropertyComponentPublic(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder}
    }

    /// Private interface of PropertyProfile
    ///
    pub resource interface PropertyProfilePrivate {
        pub fun borrowPropertyComponent(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter, TGSComponent.ComponentBase}
    }

    /// The Profile resource
    ///
    pub resource Profile: PropertyProfilePublic, PropertyProfilePrivate, TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv {
        /// Basics info
        access(contract) let appAddress: Address
        access(contract) let serviceType: Type
        /// Entity
        access(account) let virtualEntity: @TGSVirtualEntity.Entity

        init(_ appAddr: Address, _ serviceType: Type) {
            self.appAddress = appAddr
            self.serviceType = serviceType
            self.virtualEntity <- TGSVirtualEntity.create()
            self.virtualEntity.attachComponent(<- PropertyComponent.create())

            emit ProfileCreated(
                uuid: self.uuid,
                appAddress: self.appAddress
            )
        }

        destroy() {
            destroy self.virtualEntity
        }

        // ====== Public Methods ======

        /// Borrow the public property component of the profile
        ///
        pub fun borrowPropertyComponentPublic(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder} {
            return self.borrowPropertyComponent()
        }

        // ====== Private Methods ======

        /// Borrow the private property component of the profile
        ///
        pub fun borrowPropertyComponent(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter, TGSComponent.ComponentBase} {
            let propCompType = Type<@PropertyComponent.Component>()
            let comp = self.virtualEntity.borrowComponent(propCompType)
                ?? panic("Cannot borrow the property component")
            return comp as! &PropertyComponent.Component
        }

        /// Issue and return the public capablity of the profile
        ///
        pub fun issueSelfPublicCapability(
            _ storageRef: &AuthAccount.StorageCapabilities
        ): Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic}> {
            let stroageInfo = PropertyProfile.getStorageInfo()
            let cap = storageRef
                .issue<&Profile{PropertyProfilePublic, TGSAppServiceProfile.ProfileBlueprintPublic}>(stroageInfo.storagePath)

            emit PublicCapabilityIssued(
                uuid: self.uuid,
                ownerAddress: self.owner?.address
            )
            return cap
        }

        /// Issue and return the private capability of the profile
        ///
        pub fun issueSelfPrivateCapability(
            _ storageRef: &AuthAccount.StorageCapabilities,
        ): Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}> {
            let stroageInfo = PropertyProfile.getStorageInfo()
            let cap = storageRef
                .issue<&Profile{PropertyProfilePublic, PropertyProfilePrivate, TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>(stroageInfo.storagePath)

            emit PrivateCapabilityIssued(
                uuid: self.uuid,
                ownerAddress: self.owner?.address
            )
            return cap
        }
    }

    /* --- Methods --- */

    /// Returns the storage information of this contract
    ///
    pub fun getStorageInfo(): TGSInterfaces.ResourceStorageInfo {
        let identifier = "PropertyProfile_".concat(self.account.address.toString())
        return TGSInterfaces.ResourceStorageInfo(
            storagePath: StoragePath(identifier: identifier)!,
            publicPath: PublicPath(identifier: identifier)!,
            publicCapabilityType: Type<Capability<&Profile{PropertyProfilePublic, TGSAppServiceProfile.ProfileBlueprintPublic}>>(),
            privateCapabilityType: Type<Capability<&Profile{PropertyProfilePublic, PropertyProfilePrivate, TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>>()
        )
    }

    /// Creates an new Profile instance and returns it to the caller
    ///
    /// @return A new Profile resource
    ///
    access(account) fun createProfile(_ appAddr: Address, _ serviceType: Type): @Profile {
        return <- create Profile(appAddr, serviceType)
    }
}
