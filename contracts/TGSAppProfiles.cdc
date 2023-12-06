// Owned imports
import "TGSInterfaces"
import "TGSAppService"
import "TGSAppServiceProfile"

/// The contract interface for TGS Profiles Collection
///
pub contract TGSAppProfiles {
    /* --- Canonical Paths --- */
    pub let TGSApplicationProfilesStoragePath: StoragePath;
    pub let TGSApplicationProfilesPublicPath: PublicPath;

    /* --- Events --- */

    pub event ContractInitialized()
    /// Emit when the profile is generated
    pub event ProfileGenerated(address: Address, service: Type, platform: String, uid: String)
    /// Emit when the profile is taken
    pub event ProfileTaken(address: Address, service: Type, platform: String, uid: String)
    /// Emit when the profile is revoked
    pub event ProfileRevoked(address: Address, service: Type, platform: String, uid: String)

    /* --- Interfaces & Resources --- */

    pub resource interface ProfilesCollectionPublic {
        pub fun borrowProfile(service: Type, _ platform: String, _ uid: String): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}?
    }

    pub resource interface ProfilesCollectionPrivate {
        pub fun generateProfile(
            service: &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppServiceProfile.ServiceBlueprintWithProfile},
            _ platform: String,
            _ uid: String,
            _ options: {String: AnyStruct}
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}

        pub fun take(service: Type, _ platform: String, _ uid: String): @AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}
        pub fun revoke(service: Type, _ platform: String, _ uid: String)
    }

    /// Temp profile collection scored in application
    ///
    pub resource ProfilesCollection: ProfilesCollectionPublic, ProfilesCollectionPrivate {
        /// The collection of the profiles
        access(contract) let profiles: @{Type: {String: AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}}}

        init() {
            self.profiles <- {}
        }

        destroy () {
            destroy self.profiles
        }

        /* === public implementation === */

        /// Borrow the profile from the collection
        ///
        pub fun borrowProfile(
            service: Type,
            _ platform: String,
            _ uid: String
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}? {
            let platformUid = platform.concat(":").concat(uid)
            let platformProfiles = &self.profiles[service] as &{String: AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}}?
            if platformProfiles != nil {
                let profiles = platformProfiles!
                return &profiles[platformUid] as &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}?
            } else {
                return nil
            }
        }

        /* === private methods === */

        /// Generate a new profile
        ///
        pub fun generateProfile(
            service: &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppServiceProfile.ServiceBlueprintWithProfile},
            _ platform: String,
            _ uid: String,
            _ options: {String: AnyStruct}
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv} {
            let serviceType = service.getIdentityType()
            let platformUid = platform.concat(":").concat(uid)
            assert(
                self.profiles[serviceType] == nil || self.profiles[serviceType]?.containsKey(platformUid) == false,
                message: "Profile already exists"
            )

            if self.profiles[serviceType] == nil {
                self.profiles[serviceType] <-! {}
            }
            let profiles = &self.profiles[serviceType]
                as &{String: AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}}?
                ?? panic("Failed to get the reference to the profiles")
            let profile <- service.generateProfile(options)

            profiles[platformUid] <-! profile

            emit ProfileGenerated(
                address: self.owner!.address,
                service: serviceType,
                platform: platform,
                uid: uid
            )

            return self.borrowProfile(service: serviceType, platform, uid)!
        }

        /// Take the profile from the collection
        ///
        pub fun take(service: Type, _ platform: String, _ uid: String): @AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv} {
            let platformUid = platform.concat(":").concat(uid)
            assert(
                self.profiles[service]?.containsKey(platformUid) == true,
                message: "Profile not found"
            )

            let profile <- (self.profiles[service]?.remove(key: platformUid) ?? panic("Platfrom profiles not found"))
                ?? panic("Failed to take profile")

            emit ProfileTaken(
                address: self.owner!.address,
                service: service,
                platform: platform,
                uid: uid
            )

            return <- profile
        }

        /// Revoke the profile from the collection
        ///
        pub fun revoke(service: Type, _ platform: String, _ uid: String) {
            let platformUid = platform.concat(":").concat(uid)
            assert(
                self.profiles[service]?.containsKey(platformUid) == true,
                message: "Profile not found"
            )
            let profile <- (self.profiles[service]?.remove(key: platformUid) ?? panic("Platfrom profiles not found"))
                ?? panic("Failed to take profile")
            destroy profile

            emit ProfileRevoked(
                address: self.owner!.address,
                service: service,
                platform: platform,
                uid: uid
            )
        }
    }

    /* --- Methods --- */

    /// Create a new profile collection resource or issue the cap for the existing one
    /// Only can be invoked by contracts in the same account
    ///
    access(account) fun createOrIssueAppProfilesCollectionPrivCap(
        _ acct: &AuthAccount
    ): Capability<&ProfilesCollection{ProfilesCollectionPublic, ProfilesCollectionPrivate}> {
        post {
            result.check(): "Failed to create or issue the capability for the profile collection"
        }

        // ensure the resource
        if acct.borrow<&AnyResource>(from: self.TGSApplicationProfilesStoragePath) == nil {
            acct.save(<- create ProfilesCollection(), to: self.TGSApplicationProfilesStoragePath)
        }

        // re-publish the public capability
        acct.capabilities.unpublish(self.TGSApplicationProfilesPublicPath)
        let cap = acct.capabilities.storage
            .issue<&ProfilesCollection{ProfilesCollectionPublic}>(self.TGSApplicationProfilesStoragePath)
        acct.capabilities.publish(cap, at: self.TGSApplicationProfilesPublicPath)

        // return the private cap
        return acct.capabilities.storage
            .issue<&ProfilesCollection{ProfilesCollectionPublic, ProfilesCollectionPrivate}>(self.TGSApplicationProfilesStoragePath)
    }

    init() {
        let identifier = "TGSProfilesCollection_".concat(self.account.address.toString())
        self.TGSApplicationProfilesStoragePath = StoragePath(identifier: identifier)!
        self.TGSApplicationProfilesPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
