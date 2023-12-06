// Third-party imports
import "MetadataViews"
import "HybridCustody"

// Owned imports
import "TGSInterfaces"
import "TGSDataCenter"
import "TGSLogging"
import "TGSComponent"
import "TGSEntity"
import "TGSUser"
import "TGSAppProfiles"
import "PropertyComponent"
import "TGSAppService"
import "TGSAppServiceProfile"

/// The contract for the TGS App Service Kit.
///
pub contract TGSApplication: TGSEntity {
    /* --- Canonical Paths --- */
    pub let TGSApplicationKitStoragePath: StoragePath;
    pub let TGSApplicationKitPublicPath: PublicPath;

    /* --- Events --- */

    pub event ContractInitialized()

    pub event ServiceRegistered(address: Address, _ identityType: Type)

    pub event ApplicationPropertyUpdated(address: Address, key: String, _ valueType: String)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// The public interface for a TGS application
    ///
    pub resource interface ApplicationPublic {
        /// Returns all registered services
        ///
        pub fun getRegisteredServices(): [Type]

        /// Borrow the service reference from this application
        ///
        pub fun borrowServicePublic(_ identityType: Type): &AnyResource{TGSAppService.ServiceBlueprintPublic}?

        /// Returns if the service can create an app profile
        ///
        pub fun canCreateProfile(_ identityType: Type): Bool
    }

    /// The private interface for a TGS application
    ///
    pub resource interface ApplicationManager {

        /// Register a service to this application
        ///
        pub fun registerService(_ service: Capability<&AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}>) {
            pre {
                service.check(): "Invalid Service Capability"
            }
        }

        /// Borrow the service reference from this application
        ///
        pub fun borrowService(_ serviceType: Type): &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}?

        /// borrow a service with profile
        ///
        pub fun borrowServiceWithProfile(
            _ serviceType: Type
        ): &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppServiceProfile.ServiceBlueprintWithProfile}

        /// Generate a profile for the given identity type, platform and uid
        ///
        pub fun generateAndSaveProfile(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
            _ options: {String: AnyStruct}
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}

        /// Returns the profile resource based on the platform and uid
        ///
        pub fun revokeProfile(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
        )

        /// Returns if the profile is taked
        ///
        pub fun isProfileTaked(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String
        ): Bool

        /// Returns the reference of profile resource based on the platform and uid
        ///
        pub fun borrowProfile(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}?

        /// Returns the user's address
        ///
        pub fun getUserAddress(
            _ platform: String,
            _ uid: String
        ): Address? {
            return TGSDataCenter.getAddressByThirdpartyUid(platform, uid)
        }

        /// Get the profiles collection capability
        ///
        pub fun getProfilesCollection(): Capability<&TGSAppProfiles.ProfilesCollection{TGSAppProfiles.ProfilesCollectionPublic, TGSAppProfiles.ProfilesCollectionPrivate}>

        /// Borrow property component reference
        ///
        pub fun borrowPropertyComponent(): &PropertyComponent.Component
    }

    /// The application entity resource
    ///
    pub resource Entity: ApplicationPublic, ApplicationManager, TGSInterfaces.AccountManagerAccessor, TGSInterfaces.DisplayProperties, MetadataViews.Resolver, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate {
        /// Users' account manager, which is used to control users' accounts
        ///
        access(self) let accountManager: Capability<&HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}>
        /// Profiles collection, which is used to manage users' temp profiles
        ///
        access(self) let profilesCollection: Capability<&TGSAppProfiles.ProfilesCollection{TGSAppProfiles.ProfilesCollectionPublic, TGSAppProfiles.ProfilesCollectionPrivate}>
        /// All services registered to this application
        ///
        access(self) let services: {Type: Capability<&AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}>}
        /// Logging store
        ///
        access(self) let logs: [AnyStruct{TGSLogging.LogEntry}]
        /// Logging capability
        ///
        access(self) var selfLoggableCap: Capability<&AnyResource{TGSLogging.LoggableResource}>?
        /// The components of the entity
        ///
        access(contract) let components: @{Type: TGSComponent.Component}

        init(
            _ accountManager: Capability<&HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}>,
            _ profilesCol: Capability<&TGSAppProfiles.ProfilesCollection{TGSAppProfiles.ProfilesCollectionPublic, TGSAppProfiles.ProfilesCollectionPrivate}>,
        ) {
            pre {
                accountManager.check(): "Invalid Account Manager Capability"
                profilesCol.check(): "Invalid Profiles Collection Capability"
            }
            self.accountManager = accountManager
            self.profilesCollection = profilesCol
            self.services = {}
            self.logs = []
            self.selfLoggableCap = nil
            self.components <- {}
            // Attach the property component
            self.attachComponent(<- PropertyComponent.create())
        }

        destroy() {
            for k in self.components.keys {
                self.components[k]?.beforeDestory()
            }
            destroy self.components
        }

        /// ----- Loggable capability -----

        /// Sets the loggable capability
        ///
        access(contract) fun setLoggableCap(_ loggable: Capability<&AnyResource{TGSLogging.LoggableResource}>?) {
            self.selfLoggableCap = loggable
        }

        /// Returns the loggable capability
        ///
        access(contract) fun getLoggableCap(): Capability<&AnyResource{TGSLogging.LoggableResource}>? {
            return self.selfLoggableCap
        }

        /* === public implementation === */

        pub fun getRegisteredServices(): [Type] {
            return self.services.keys
        }

        pub fun borrowServicePublic(_ identityType: Type): &AnyResource{TGSAppService.ServiceBlueprintPublic}? {
            if let service: Capability<&AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}> = self.services[identityType] {
                return service.borrow()
            }
            return nil
        }

        /// Returns the types of supported views - none at this time
        ///
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        /// Resolves the given view if supported - none at this time
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.getName(),
                        description: self.getDescription(),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.getImage()
                        )
                    )
            }
            return nil
        }

        pub fun getProperty(_ key: String): AnyStruct? {
            return self.getPropertyInternal("_external:".concat(key))
        }

        /// Returns if the service can create an app profile
        ///
        pub fun canCreateProfile(_ identityType: Type): Bool {
            let service = self.borrowServiceWithProfile(identityType)
            return service != nil
        }

        /* ---- implemation of TGSLogging.LoggableResource ---- */

        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]? {
            return &self.logs as &[AnyStruct{TGSLogging.LogEntry}]
        }

        /* === Resource non-public methods - Admin === */

        /// Return the property value for the given key
        ///
        access(contract) fun getPropertyInternal(_ key: String): AnyStruct? {
            let propComp = self.borrowPropertyComponent()
            return propComp.getProperty(key)
        }

        /// Set property internal method
        ///
        access(contract) fun setPropertyInternal(_ key: String, _ value: AnyStruct) {
            let propComp = self.borrowPropertyComponent()
            propComp.setPropertyRaw(key, value)

            emit ApplicationPropertyUpdated(
                address: self.getOwnerAddress(),
                key: key,
                value.getType().identifier
            )

            // action logging
            self.log(
                source: self.getType(),
                action: "setProperty",
                message: "Key: ".concat(key).concat(" ValueType: ".concat(value.getType().identifier))
            )
        }

        /// Get the profiles collection
        ///
        pub fun getProfilesCollection(): Capability<&TGSAppProfiles.ProfilesCollection{TGSAppProfiles.ProfilesCollectionPublic, TGSAppProfiles.ProfilesCollectionPrivate}> {
            return self.profilesCollection
        }

        /// Borrow property component reference
        ///
        pub fun borrowPropertyComponent(): &PropertyComponent.Component {
            let comp = self.borrowComponent(Type<@PropertyComponent.Component>())
            return (comp as! &PropertyComponent.Component?)
                ?? panic("Failed to load property component")
        }

        /* === AccountManagerAccessor methods === */

        /// Returns the account manager capability
        ///
        pub fun getAccountManager(): Capability<&HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}> {
            return self.accountManager
        }

        /* === ApplicationManager methods === */

        /// Register a service to this application
        ///
        pub fun registerService(_ service: Capability<&AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}>) {
            pre {
                service.check(): "Invalid Service Capability"
            }
            let serviceRef = service.borrow()!
            let identityType = serviceRef.getIdentityType()
            assert(
                self.services[identityType] == nil,
                message: "Service already registered"
            )

            self.services[identityType] = service

            emit ServiceRegistered(address: self.getOwnerAddress(), serviceRef.getIdentityType())

            self.log(
                source: self.getType(),
                action: "registerService",
                message: "Service: ".concat(serviceRef.getIdentityType().identifier)
            )
        }

        /// Returns the service reference for the given identity type
        ///
        pub fun borrowService(_ identityType: Type): &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}? {
            if let service = self.services[identityType] {
                return service.borrow()
            }
            return nil
        }

        /// borrow a service with profile
        ///
        pub fun borrowServiceWithProfile(
            _ serviceType: Type
        ): &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppServiceProfile.ServiceBlueprintWithProfile} {
            let serv = self.borrowService(serviceType)
                ?? panic("Failed to borrow service")
            return serv.borrowSelf()
                as! &AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppServiceProfile.ServiceBlueprintWithProfile}
        }

        /// Generates and saves a profile for the user
        ///
        pub fun generateAndSaveProfile(
            _ identityType: Type,
            _ platform: String,
            _ uid: String,
            _ options: {String: AnyStruct}
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv} {
            let appProfiles = self.profilesCollection.borrow()
                ?? panic("Profiles collection is not available")
            let service = self.borrowServiceWithProfile(identityType)
            // General the profile
            let profileRef = appProfiles.generateProfile(
                service: service,
                platform, uid, options
            )

            self.log(
                source: self.getType(),
                action: "generateAndSaveProfile",
                message: "Service: ".concat(identityType.identifier)
                    .concat("\nPlatform: ").concat(platform)
                    .concat("\nUid: ").concat(uid)
            )
            return profileRef
        }


        /// Returns if the profile is taked
        ///
        pub fun isProfileTaked(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String
        ): Bool {
            let appProfiles = self.profilesCollection.borrow()
                ?? panic("Profiles collection is not available")
            let service = self.borrowServiceWithProfile(serviceType)
            return appProfiles.borrowProfile(service: serviceType, platform, uid) == nil
        }

        /// Returns the profile resource based on the platform and uid
        ///
        pub fun revokeProfile(
            _ identityType: Type,
            _ platform: String,
            _ uid: String,
        ) {
            let appProfiles = self.profilesCollection.borrow()
                ?? panic("Profiles collection is not available")

            // only the profile in the collection can be revoked
            if appProfiles.borrowProfile(service: identityType, platform, uid) == nil {
                assert(
                    TGSDataCenter.getAddressByThirdpartyUid(platform, uid) == nil,
                    message: "Cannot revoke profile that is not in the application's profiles collection"
                )
                return
            }

            // General the profile
            appProfiles.revoke(service: identityType, platform, uid)

            self.log(
                source: self.getType(),
                action: "revokeProfile",
                message: "Service: ".concat(identityType.identifier)
                    .concat("\nPlatform: ").concat(platform)
                    .concat("\nUid: ").concat(uid)
            )
        }

        /// Returns the reference of profile resource based on the platform and uid
        ///
        pub fun borrowProfile(
            _ serviceType: Type,
            _ platform: String,
            _ uid: String
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}? {
            pre {
                self.accountManager.check(): "Invalid Account Manager Capability"
                self.profilesCollection.check(): "Invalid Profiles Collection Capability"
            }
            let service = self.borrowServiceWithProfile(serviceType)

            // borrow the profile from the collection
            if let profile = self.profilesCollection.borrow()!.borrowProfile(service: serviceType, platform, uid) {
                return profile.borrowSelf()
            }

            // try to borrow the profile from their own address
            let address = TGSDataCenter.getAddressByThirdpartyUid(platform, uid)
            if address == nil {
                return nil
            }

            // borrow the child account from the account manager
            if let childAccount = self.accountManager.borrow()!.borrowAccount(addr: address!) {
                let profileStorageInfo = service.getProfileStorageInfo()
                // get cap from the child account
                if let cap = childAccount.getPrivateCapFromDelegator(type: profileStorageInfo.privateCapabilityType) {
                    // downcast the cap to profile capability
                    if let profileCap = cap as? Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}> {
                        // borrow the profile from the capability
                        return profileCap.borrow()
                    }
                }
            }

            // otherwise, return nil
            return nil
        }

        /* === Internal methods === */

    }

    /* --- Methods --- */

    /// Creates a new application resource
    /// Only can be invoked by contracts in the same account
    ///
    access(account) fun createNewApplication(
        _ accountManager: Capability<&HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}>,
        _ profilesCol: Capability<&TGSAppProfiles.ProfilesCollection{TGSAppProfiles.ProfilesCollectionPublic, TGSAppProfiles.ProfilesCollectionPrivate}>,
    ): @Entity {
        return <- create Entity(accountManager, profilesCol)
    }

    /// Issue and publish the application public capability
    ///
    access(account) fun issueAndPublishApplicationPubCap(
        _ acctCapabilities: &AuthAccount.Capabilities
    ): Capability<&Entity{ApplicationPublic, MetadataViews.Resolver}> {
        post {
            result.check(): "Invalid capability"
        }
        acctCapabilities.unpublish(self.TGSApplicationKitPublicPath)
        let cap = acctCapabilities.storage
            .issue<&Entity{ApplicationPublic, MetadataViews.Resolver}>(self.TGSApplicationKitStoragePath)
        acctCapabilities.publish(cap, at: self.TGSApplicationKitPublicPath)
        return cap
    }

    /// Issue the application private capability
    ///
    access(account) fun issueApplicationPrivCap(
        _ acctStorageRef: &AuthAccount.StorageCapabilities
    ): Capability<&Entity{ApplicationPublic, ApplicationManager, TGSInterfaces.AccountManagerAccessor, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}> {
        post {
            result.check(): "Invalid capability"
        }
        return acctStorageRef.issue<&Entity{ApplicationPublic, ApplicationManager, TGSInterfaces.AccountManagerAccessor, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}>
            (self.TGSApplicationKitStoragePath)
    }

    /// Issue the application's AccountManagerAccessor capability
    ///
    access(account) fun issueApplicationAccountManagerAccessorCap(
        _ acctStorageRef: &AuthAccount.StorageCapabilities
    ): Capability<&Entity{TGSInterfaces.AccountManagerAccessor, MetadataViews.Resolver, TGSLogging.LoggableResource}> {
        post {
            result.check(): "Failed to issue account manager accessor capability"
        }
        return acctStorageRef.issue<&Entity{TGSInterfaces.AccountManagerAccessor, MetadataViews.Resolver, TGSLogging.LoggableResource}>
            (self.TGSApplicationKitStoragePath)
    }

    /// Returns the application public capability type
    ///
    pub fun getApplicationPublicCapabilityType(): Type {
        return Type<Capability<&Entity{ApplicationPublic, MetadataViews.Resolver}>>()
    }

    /// Returns the application private capability type
    ///
    pub fun getApplicationPrivateCapabilityType(): Type {
        return Type<Capability<&Entity{ApplicationPublic, ApplicationManager, TGSInterfaces.AccountManagerAccessor, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}>>()
    }

    /// Returns the application public capability for the given address
    ///
    pub fun getApplicationPublicCapability(
        addr: Address
    ): Capability<&Entity{ApplicationPublic, MetadataViews.Resolver}>? {
        return getAccount(addr).capabilities
            .get<
                &Entity{ApplicationPublic, MetadataViews.Resolver}
            >(self.TGSApplicationKitPublicPath)
    }

    init() {
        let identifier = "TGSApplicationKit_".concat(self.account.address.toString())
        self.TGSApplicationKitStoragePath = StoragePath(identifier: identifier)!
        self.TGSApplicationKitPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
