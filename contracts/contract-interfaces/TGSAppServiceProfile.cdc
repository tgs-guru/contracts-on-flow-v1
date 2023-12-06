// Third-party imports
import "MetadataViews"

// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "TGSVirtualEntity"

/// The contract interface for the profile resource of TGS Application Service
///
pub contract interface TGSAppServiceProfile {

    /* --- Interfaces & Resources --- */

    pub resource interface ServiceBlueprintWithProfile {
        /// Returns the profile resource based on the platform and uid
        ///
        pub fun generateProfile(_ options: {String: AnyStruct}): @AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv}

        /// Return the storage information of this profile resource
        ///
        pub fun getProfileStorageInfo(): TGSInterfaces.ResourceStorageInfo
    }

    /// The public interface for a profile
    ///
    pub resource interface ProfileBlueprintPublic {
        /// Returns the identity type of this profile
        ///
        pub view fun getServiceIdentityType(): Type

        /// Returns if the profile is attached to the TGSUser Account
        ///
        pub view fun isAttached(): Bool
    }

    /// The lifecycle interface for a blueprint
    ///
    pub resource interface ProfileBlueprintPriv {
        /// Sets the parent of this profile
        ///
        pub fun setParent(_ parent: Capability<&AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}>?)

        /// Returns the auth ref of this service
        ///
        pub fun borrowSelf(): auth &AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv}

        /// Borrow the reference of the lifecycle component
        ///
        pub fun borrowVirtualEntity(): &TGSVirtualEntity.Entity

        /// Issue and return the public capablity of the profile
        ///
        pub fun issueSelfPublicCapability(
            _ storageRef: &AuthAccount.StorageCapabilities,
        ): Capability<&AnyResource{ProfileBlueprintPublic}>

        /// Issue and return the private capability of the profile
        ///
        pub fun issueSelfPrivateCapability(
            _ storageRef: &AuthAccount.StorageCapabilities,
        ): Capability<&AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv}>
    }

    pub resource Profile: ProfileBlueprintPublic, ProfileBlueprintPriv {
        access(contract) let appAddress: Address
        access(contract) let serviceType: Type
        access(account) let virtualEntity: @TGSVirtualEntity.Entity

        // ====== Public Methods ======

        /// Returns the identity type of this profile
        ///
        pub view fun getServiceIdentityType(): Type {
            return self.serviceType
        }

        /// Returns if the profile is attached to the TGSUser Account
        ///
        pub view fun isAttached(): Bool {
            return self.virtualEntity.isActive()
        }

        // ====== Private Methods ======

        /// Returns the auth ref of this service
        ///
        pub fun borrowSelf(): auth &AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv} {
            return &self as auth &AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv}
        }

        /// Borrow the reference of the lifecycle component
        ///
        pub fun borrowVirtualEntity(): &TGSVirtualEntity.Entity {
            return &self.virtualEntity as &TGSVirtualEntity.Entity
        }

        /// Sets the parent of this profile
        ///
        pub fun setParent(_ parent: Capability<&AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}>?) {
            pre {
                self.isAttached() == false: "Profile is already attached"
            }
            self.virtualEntity.setParent(parent)
        }

        /// Issue and return the public capablity of the profile
        ///
        pub fun issueSelfPublicCapability(
            _ storageRef: &AuthAccount.StorageCapabilities,
        ): Capability<&AnyResource{ProfileBlueprintPublic}>

        /// Issue and return the private capability of the profile
        ///
        pub fun issueSelfPrivateCapability(
            _ storageRef: &AuthAccount.StorageCapabilities,
        ): Capability<&AnyResource{ProfileBlueprintPublic, ProfileBlueprintPriv}>

        /// ===== internal methods =====

        // NOTHING
    }

    /* --- Methods --- */

    /// Creates an new Profile instance and returns it to the caller
    ///
    /// @return A new Profile resource
    ///
    access(account) fun createProfile(_ appAddr: Address, _ serviceType: Type): @Profile
}
