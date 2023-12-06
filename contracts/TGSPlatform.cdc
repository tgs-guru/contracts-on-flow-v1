// Third-party imports
import "MetadataViews"
import "HybridCustody"
import "CapabilityDelegator"
import "CapabilityFactory"
import "CapabilityFilter"
import "HybridCustodyHelper"

// Owned imports
import "TGSInterfaces"
import "TGSDataCenter"
import "TGSLogging"
import "TGSComponent"
import "TGSEntity"
import "TGSUser"
import "TGSAppProfiles"
import "TGSApplication"
import "PropertyComponent"
import "TGSAppService"
import "TGSAppServiceProfile"

/// The contract for TGS Platform general management
///
pub contract TGSPlatform: TGSEntity {
    /* --- Canonical Paths --- */
    pub let TGSPlatformStoragePath: StoragePath;
    pub let TGSPlatformPublicPath: PublicPath;

    /* --- Events --- */

    pub event ContractInitialized()
    pub event PlatformInitialized()

    /// Event emitted when a new application is registered
    ///     address: application account
    ///     name: application name
    pub event ApplicationInitialized(address: Address, name: String)
    /// Event emitted when a new application service is attached to the application
    ///     address: application account
    ///     service: service resource identifier
    pub event ApplicationServiceRegistered(address: Address, service: String)

    /// Event emitted when a new user is registered
    ///     address: user account
    pub event UserInitialized(address: Address)

    /// Event emitted when a new user profile is taken from the application
    ///     appAddr: application address
    ///     identityType: identity type
    ///     platform: platform name
    ///     uid: user id
    ///     userAddr: user address
    pub event UserProfileTakedFromApplication(
        appAddr: Address,
        identityType: Type,
        platform: String,
        uid: String,
        userAddr: Address
    )

    /// Event emitted when the controller capability is published
    ///     recipient: recipient address
    pub event ControllerPublished(recipient: Address)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// Public interface for TGS platform
    ///
    pub resource interface PlatformPublic {
        /// Get the platform owner address
        ///
        pub fun getAddress(): Address

        /// Get the application address by name
        ///
        pub fun getApplicationAddress(_ name: String): Address?
    }

    /// Admin interface for TGS platform, which will be used as a private capability
    /// This interface is the capability used to configure the platform, such as set properties, etc.
    /// This capability is used by the platform admin by flow-cli or other tools.
    ///
    pub resource interface PlatformAdmin {
        /// Publish the controller capability to recipient
        ///
        pub fun publishControllerCapability(to: Address)
    }

    /// Controller interface for TGS platform, which will be used as a private capability.
    /// This interface is the capability used to control the platform, such as adding new application, etc.
    /// It is different from the admin interface, This capability is used to control the platform by backend services.
    ///
    pub resource interface PlatformController {
        /// Borrow profile's private property component reference
        ///
        pub fun borrowPlatformPropertyComponent(): &PropertyComponent.Component

        /// Create a new application account
        ///
        pub fun initializeNewApplicationAccount(
            name: String,
            _ appAcct: Capability<&AuthAccount>,
        ): &TGSApplication.Entity

        /// Get the application address by name
        ///
        pub fun getApplicationAddress(_ name: String): Address?

        /// Register a new service resource to application
        ///
        pub fun registerApplicationService(
            _ appAddr: Address,
            service: @AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}
        )

        /// Borrow the application private capability
        ///
        pub fun borrowApplicationPrivate(
            _ appAddr: Address,
        ): &TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}?

        /// Create a new tgs user
        ///
        pub fun initializeNewUserAccount(
            _ userAcct: Capability<&AuthAccount>,
        ): &TGSUser.Entity

        /// Borrow the user private capability
        ///
        pub fun borrowUser(
            _ userAddr: Address,
        ): &TGSUser.Entity{TGSUser.UserPublic, TGSUser.UserPrivate, TGSUser.BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}?

        /// Take user's profile for some service from the application
        ///
        pub fun takeUserProfileFromApplication(
            _ appAddr: Address,
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
            _ userAddr: Address
        )

        /// Borrow user's profile from application or user's account
        ///
        pub fun borrowUserProfile(
            _ appAddr: Address,
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}?
    }

    /// The resource for TGS platform
    ///
    pub resource Entity: PlatformPublic, PlatformAdmin, PlatformController, MetadataViews.Resolver, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate {
        access(self) let hcwrapper: @HybridCustodyHelper.Wrapper
        /// Logging store
        access(self) let logs: [AnyStruct{TGSLogging.LogEntry}]
        /// Logging capability
        access(self) var selfLoggableCap: Capability<&AnyResource{TGSLogging.LoggableResource}>?
        /// The components of the entity
        access(contract) let components: @{Type: TGSComponent.Component}
        /// A mapping from application name to application address
        access(self) let appNameMappping: {String: Address}

        init(
            _ acctCap: Capability<&AuthAccount>,
        ) {
            // capabilities
            self.hcwrapper <- HybridCustodyHelper.createWrapper(acctCap)
            self.hcwrapper.ensureManagerExists()
            self.appNameMappping = {}
            // components
            self.components <- {}
            // loggable
            self.logs = []
            self.selfLoggableCap = nil

            // Attach the property component
            self.attachComponent(<- PropertyComponent.create())
        }

        destroy() {
            for k in self.components.keys {
                self.components[k]?.beforeDestory()
            }
            destroy self.components

            destroy self.hcwrapper
        }

        /// Initialize the TGSPlatform, resource method
        ///
        pub fun initialize() {
            pre {
                !self.isActive(): "TGSPlatform is already initialized"
            }
            // ensure owner exisrs
            self.getOwnerAddress()

            // publish the public capability
            self.issueAndPublishPublicCapablity()
            // initialize components
            self.activate(self.issueLoggableCapability())

            // action logging
            self.log(
                source: self.getType(),
                action: "initialize",
                message: "Address: ".concat(self.getOwnerAddress().toString())
            )
        }

        /* === public implementation === */

        /// Get the platform owner address
        ///
        pub fun getAddress(): Address {
            return self.getOwnerAddress()
        }

        /// Get the application address by name
        ///
        pub fun getApplicationAddress(_ name: String): Address? {
            return self.appNameMappping[name]
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

        /* ---- implemation of TGSLogging.LoggableResource ---- */

        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]? {
            return &self.logs as &[AnyStruct{TGSLogging.LogEntry}]
        }

        /* === PlatformAdmin methods === */

        /// Publish the controller capability to the given address
        ///
        pub fun publishControllerCapability(to: Address) {
            let acct = self.hcwrapper.borrowManagerAuthAccount()
            let controllerCap = acct.capabilities.storage
                .issue<&Entity{PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>(TGSPlatform.TGSPlatformStoragePath)
            assert(controllerCap.check(), message: "Failed to issue controller capability")

            let identifier = TGSPlatform.getControllerIdentifier(to)

            acct.inbox.publish(controllerCap, name: identifier, recipient: to)

            emit ControllerPublished(recipient: to)

            self.log(
                source: self.getType(),
                action: "publishControllerCapability",
                message: "Controller published to: ".concat(to.toString())
            )
        }

        /* === Platform Controller methods === */

        /// Borrow profile's private property component reference
        ///
        pub fun borrowPlatformPropertyComponent(): &PropertyComponent.Component {
            let comp = self.borrowComponent(Type<@PropertyComponent.Component>())
            return comp as? &PropertyComponent.Component
                ?? panic("Failed to load property component")
        }

        /// Init the new application account
        ///
        pub fun initializeNewApplicationAccount(
            name: String,
            _ appAcct: Capability<&AuthAccount>,
        ): &TGSApplication.Entity {
            pre {
                self.appNameMappping[name] == nil: "The application name already exists"
            }
            // Ensure the application account is valid and borrow the referrence
            let applicationAcct = self._ensureAuthAccountValidAndBorrow(appAcct)

            // create a temp wrapper for hybrid custody
            let appWrapper <- HybridCustodyHelper.createWrapper(appAcct)
            // Create a new HybridCustody manager in the application account
            appWrapper.ensureManagerExists()

            // Ensure the application account is not initialized
            assert(
                applicationAcct.borrow<&AnyResource>(from: TGSApplication.TGSApplicationKitStoragePath) == nil,
                message: "Application account already initialized"
            )

            // Create a new application resource
            let application <- TGSApplication.createNewApplication(
                appWrapper.issueManagerPrivateCapability(),
                TGSAppProfiles.createOrIssueAppProfilesCollectionPrivCap(applicationAcct)
            )
            // destory the appWrapper, no longer needed
            destroy appWrapper
            // save the application
            applicationAcct.save(<- application, to: TGSApplication.TGSApplicationKitStoragePath)

            // publish public capability
            TGSApplication.issueAndPublishApplicationPubCap(
                &applicationAcct.capabilities as &AuthAccount.Capabilities
            )

            // initialize the application
            let appRef = applicationAcct.borrow<&TGSApplication.Entity>(from: TGSApplication.TGSApplicationKitStoragePath)
                ?? panic("Failed to borrow application resource")
            // Set the name
            appRef.setName(name)

            // issue an account manager accessor capability to the service
            let entityCap = TGSApplication.issueApplicationAccountManagerAccessorCap(
                &applicationAcct.capabilities.storage as &AuthAccount.StorageCapabilities
            )
            appRef.activate(entityCap)

            // set name mapping
            self.appNameMappping[name] = applicationAcct.address

            // ---- Hybrid Custody ----

            // Add application account as a child account of the platform account
            self.hcwrapper.setupNewChild(appAcct)

            // Add Application capability to Hybrid Custody
            let appPrivCap = TGSApplication.issueApplicationPrivCap(
                &applicationAcct.capabilities.storage as &AuthAccount.StorageCapabilities
            )
            self.hcwrapper.addCapabilityToOwnedChild(
                appAcct.address,
                capability: appPrivCap,
                isPublic: false
            )

            emit ApplicationInitialized(
                address: applicationAcct.address,
                name: name
            )

            return appRef
        }

        /// Register a new service resource to application
        ///
        pub fun registerApplicationService(
            _ appAddr: Address,
            service: @AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}
        ) {
            let application = self.borrowApplicationPrivate(appAddr)
                ?? panic("Failed to borrow application resource")

            // borrow application account to save service
            let applicationAcct = self.hcwrapper.borrowChildAuthAccount(appAddr)
                ?? panic("Failed to borrow application account")
            // The App Account needs to have sufficient Flow as storage fee
            assert(applicationAcct.availableBalance > 0.0, message: "Not enough Flow in the application account")

            // Save the service resource to the application account
            let serviceStorageInfo = service.getStorageInfo()
            if let anything = applicationAcct.borrow<&AnyResource>(from: serviceStorageInfo.storagePath) {
                panic(
                    "There is something in the service storage path: "
                    .concat(serviceStorageInfo.storagePath.toString())
                    .concat(" - ")
                    .concat(anything.getType().identifier)
                )
            }
            let identityType = service.getIdentityType()
            // save service to the storage path
            applicationAcct.save(<- service, to: serviceStorageInfo.storagePath)

            // publish service's public capability
            let pubCap = applicationAcct.capabilities.storage
                .issue<&AnyResource{TGSAppService.ServiceBlueprintPublic}>(serviceStorageInfo.storagePath)
            assert(pubCap.check(), message: "Failed to issue service public capability")
            applicationAcct.capabilities.publish(pubCap, at: serviceStorageInfo.publicPath)

            // register the service to the application
            let privCap = applicationAcct.capabilities.storage
                .issue<&AnyResource{TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate}>(serviceStorageInfo.storagePath)
            assert(privCap.check(), message: "Failed to issue service private capability")
            application.registerService(privCap)

            // Ensure service can be borrowed from application
            let serviceRef = application.borrowService(identityType)
                ?? panic("Failed to borrow service resource")

            // issue an account manager accessor capability to the service
            let acmAccessorCap = TGSApplication.issueApplicationAccountManagerAccessorCap(
                &applicationAcct.capabilities.storage as &AuthAccount.StorageCapabilities
            )
            // Call on registered in the service resource
            serviceRef.onRegister(acmAccessorCap)

            emit ApplicationServiceRegistered(
                address: appAddr,
                service: identityType.identifier
            )
        }

        /// Borrow the application private capability
        ///
        pub fun borrowApplicationPrivate(
            _ appAddr: Address
        ): &TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager,  TGSInterfaces.DisplayProperties, MetadataViews.Resolver}? {
            let appPrivCapType = TGSApplication.getApplicationPrivateCapabilityType()
            // borrow capability from delegator
            if let cap = self.hcwrapper.getCapabilityFromDelegator(
                appAddr,
                type: appPrivCapType
            ) {
                let appPrivCap = cap as! Capability<&TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager,  TGSInterfaces.DisplayProperties, MetadataViews.Resolver}>
                return appPrivCap.borrow()
            }
            return nil
        }

        /// Create a new tgs user
        ///
        pub fun initializeNewUserAccount(
            _ userCap: Capability<&AuthAccount>,
        ): &TGSUser.Entity {
            // Ensure the user account is valid and borrow the referrence
            let userAcct = self._ensureAuthAccountValidAndBorrow(userCap)

            if userAcct.borrow<&AnyResource>(from: TGSUser.TGSUserStoragePath) == nil {
                // For User account not initialized, Create a new TGSUser resource
                // The TGS user resource will be created in the method
                TGSUser.createUser(userCap)
            } else {
                // DO Nothing
            }

            // ---- Hybrid Custody ----

            // Add application account as a child account of the platform account
            self.hcwrapper.setupNewChild(userCap)

            // Add Application capability to Hybrid Custody
            let userRef = userAcct.borrow<&TGSUser.Entity>(from: TGSUser.TGSUserStoragePath)
                ?? panic("Failed to borrow user reference")
            self.hcwrapper.addCapabilityToOwnedChild(
                userAcct.address,
                capability: userRef.issueUserPrivCap(),
                isPublic: false
            )

            emit UserInitialized(
                address: userAcct.address
            )

            return userAcct.borrow<&TGSUser.Entity>(from: TGSUser.TGSUserStoragePath)
                ?? panic("Failed to borrow user resource")
        }

        /// Borrow the user private capability
        ///
        pub fun borrowUser(
            _ userAddr: Address,
        ): &TGSUser.Entity{TGSUser.UserPublic, TGSUser.UserPrivate, TGSUser.BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}? {
            let userPrivCapType = TGSUser.getUserPrivateCapabilityType()
            // borrow capability from delegator
            if let cap = self.hcwrapper.getCapabilityFromDelegator(
                userAddr,
                type: userPrivCapType
            ) {
                let userPrivCap = cap as! Capability<&TGSUser.Entity{TGSUser.UserPublic, TGSUser.UserPrivate, TGSUser.BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}>
                return userPrivCap.borrow()
            }
            return nil
        }

        /// Take user's profile for some service from the application
        /// The user's profile will be saved in the service's profiles collection
        /// The application and user should be child accounts of the platform
        ///
        pub fun takeUserProfileFromApplication(
            _ appAddr: Address,
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
            _ userAddr: Address
        ) {
            pre {
                self._isChildOwnedAccount(appAddr): "Application is not a child account of the platform"
                self._isChildOwnedAccount(userAddr): "User is not a child account of the platform"
            }
            // [0] borrow related references, application's and user's
            // borrow reference to application private capability
            let appPrivRef = self.borrowApplicationPrivate(appAddr)
                ?? panic("Failed to borrow application private reference")
            // borrow profiles collection
            let profilesCol = appPrivRef.getProfilesCollection()
                .borrow() ?? panic("Failed to borrow profiles collection")
            // borrow reference to user private capability
            let userPrivRef = self.borrowUser(userAddr)
                ?? panic("Failed to borrow user private reference")

            // [1] ensure user's address is relavent to the platform info
            // ensure user address is same as the address in data center
            if let userAddrFromDC = TGSDataCenter.getAddressByThirdpartyUid(platform, uid) {
                assert(
                    userAddrFromDC == userAddr,
                    message: "User Address is not the address in the data center"
                )
            } else {
                // save the address to user
                userPrivRef.upsertIdentity(TGSUser.ThirdPartyInfo(TGSUser.EcosystemIdentity(platform, uid), nil))
            }

            // [2] take profile from application's profiles collection
            let profile <- profilesCol.take(service: serviceType, platform, uid)

            // [3] save profile resource to user account and create + publish capability
            let service = appPrivRef.borrowServiceWithProfile(serviceType)
            // get profile storage info from the service
            let profileStorageInfo = service.getProfileStorageInfo()

            // borrow user's AuthAccount
            let userAcct = self.hcwrapper.borrowChildAuthAccount(userAddr)
                ?? panic("Failed to borrow user account")
            assert(
                userAcct.borrow<&AnyResource>(from: profileStorageInfo.storagePath) == nil,
                message: "Profile exists in the path:".concat(profileStorageInfo.storagePath.toString())
            )
            // save profile to user account
            userAcct.save(<- profile, to: profileStorageInfo.storagePath)

            // [4] setup profile's capability
            let profileRef = userAcct
                .borrow<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>(from: profileStorageInfo.storagePath)
                ?? panic("Failed to borrow profile reference")
            // issue and publish public capability
            let userStorageRef = &userAcct.capabilities.storage as &AuthAccount.StorageCapabilities
            let profilePubCap = profileRef.issueSelfPublicCapability(userStorageRef)
            userAcct.capabilities.unpublish(profileStorageInfo.publicPath)
            userAcct.capabilities.publish(profilePubCap, at: profileStorageInfo.publicPath)

            // [5] issue and attach the profile to TGSUser
            let userProfilePrivCap = profileRef.issueSelfPrivateCapability(userStorageRef)
            userPrivRef.attachProfileCapability(userProfilePrivCap)

            // [6] add the capability to application
            let appACM = appPrivRef.getAccountManager()
                .borrow() ?? panic("Failed to borrow account manager.")
            // borrow user's owned account from global hcwrapper
            let userOwnedAccount = self.hcwrapper.borrowChildOwnedAccount(userAddr)
                ?? panic("Failed borrow user OwnedAccount")

            // if you can get child from the application's account manager, the child acount should exist
            let childAcct = appACM.borrowAccount(addr: userAddr)
            // ensure user account is one child account of the application
            if childAcct == nil {
                // publish to application account's inbox
                userOwnedAccount.publishToParent(
                    parentAddress: appAddr,
                    // The factory manager is used to fetch capabilities through capability factory
                    factory: self.hcwrapper.fetchOrCreateCapabilityFactory(),
                    // you can change the filter later, currently use allow all
                    filter: self.hcwrapper.fetchOrCreateAllowAllCapabilityFilter(),
                )
                // claim from application account's inbox
                let appAcct = self.hcwrapper.borrowChildAuthAccount(appAddr)
                    ?? panic("Failed to borrow application account")
                let childAccountInboxName = HybridCustody.getChildAccountIdentifier(appAddr)
                let childAccountCap = appAcct.inbox
                    .claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(
                        childAccountInboxName,
                        provider: userAddr
                    )
                    ?? panic("child account cap not found")
                appACM.addAccount(cap: childAccountCap)
            }

            assert(
                appACM.borrowAccount(addr: userAddr) != nil,
                message: "Failed to add user as a child account of application."
            )

            // add capability to application's delegator
            userOwnedAccount.addCapabilityToDelegator(
                parent: appAddr,
                cap: userProfilePrivCap,
                isPublic: false
            )

            // emit the profile take event
            emit UserProfileTakedFromApplication(
                appAddr: appAddr,
                identityType: serviceType,
                platform: platform,
                uid: uid,
                userAddr: userAddr
            )
        }

        /// Borrow user's service profile from application or user's account
        ///
        pub fun borrowUserProfile(
            _ appAddr: Address,
            _ serviceType: Type,
            _ platform: String,
            _ uid: String,
        ): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}? {
            pre {
                self._isChildOwnedAccount(appAddr): "Application is not a child account of the platform"
            }
            // borrow reference to application private capability
            let appPrivRef = self.borrowApplicationPrivate(appAddr)
                ?? panic("Failed to borrow application private reference")
            return appPrivRef.borrowProfile(serviceType, platform, uid)
        }

        /* === Internal methods === */

        /// Issue a new loggable capability
        ///
        access(self) fun issueLoggableCapability(): Capability<&AnyResource{TGSLogging.LoggableResource}> {
            post {
                result.check(): "Invalid loggable capability"
            }
            let acct = self.hcwrapper.borrowManagerAuthAccount()
            return acct.capabilities.storage
                .issue<&Entity{TGSLogging.LoggableResource}>(TGSPlatform.TGSPlatformStoragePath)
        }

        /// Issue and publish the new public capability
        ///
        access(self) fun issueAndPublishPublicCapablity() {
            let acct = self.hcwrapper.borrowManagerAuthAccount()
            if acct.capabilities.get<&AnyResource>(TGSPlatform.TGSPlatformPublicPath) != nil {
                acct.capabilities.unpublish(TGSPlatform.TGSPlatformPublicPath)
            }
            // issue public capability
            let cap = acct
                .capabilities.storage
                .issue<&Entity{PlatformPublic}>(TGSPlatform.TGSPlatformStoragePath)
            assert(cap.check(), message: "Invalid user public capability")
            // public public capability
            acct.capabilities.publish(cap, at: TGSPlatform.TGSPlatformPublicPath)
        }

        /// Check if the address is a child account of the platform
        ///
        access(self) view fun _isChildOwnedAccount(_ addr: Address): Bool {
            return self.hcwrapper.borrowChildOwnedAccount(addr) != nil
        }

        /// Ensure the account is valid and borrow a reference
        ///
        access(self) fun _ensureAuthAccountValidAndBorrow(
            _ acct: Capability<&AuthAccount>,
        ): &AuthAccount {
            pre {
                acct.check(): "invalid auth account capability"
            }
            // The App Account needs to have sufficient Flow as storage fee
            return acct.borrow() ?? panic("Failed to borrow application account")
        }
    }

    /* --- Methods --- */

    /// Create a new TGS platform
    /// Only account address can create a new platform
    ///
    pub fun createTGSPlatform(
        _ acctCap: Capability<&AuthAccount>,
    ) {
        pre {
            acctCap.check(): "invalid auth account capability"
            acctCap.address == self.account.address: "Restrict to the account address."
        }
        let acct = acctCap.borrow() ?? panic("Auth account not exists")

        // Check if the TGS Platfrom exists
        assert(
            acct.borrow<&AnyResource>(from: self.TGSPlatformStoragePath) == nil,
            message: "TGS Platform already exists"
        )

        // create the platform resource
        let platform <- create Entity(acctCap)
        // save the platform resource to storage
        acct.save(<-platform, to: self.TGSPlatformStoragePath)

        let platformRef = acct.borrow<&Entity>(from: self.TGSPlatformStoragePath)
            ?? panic("TGS Platform not exists")
        platformRef.initialize()

        // emit event
        emit PlatformInitialized()
    }

    /// Borrow the TGS platform resource
    ///
    pub fun borrowPlatformPublic(): &Entity{PlatformPublic} {
        let cap = getAccount(self.account.address)
            .capabilities
            .get<&Entity{PlatformPublic}>(self.TGSPlatformPublicPath) ?? panic("TGS Platform public capability not exists")
        return cap.borrow() ?? panic("Failed to borrow TGS Platform public")
    }

    /// Utility function to get the path identifier for the platform controller
    ///
    pub fun getControllerIdentifier(_ addr: Address): String {
        return "PlatformController_".concat(addr.toString())
    }

    /// Utility function to get the path for the platform controller
    ///
    pub fun getStandardControllerPath(_ addr: Address): StoragePath {
        let identifier = "TGSPlatform_".concat(self.account.address.toString())
        return StoragePath(
            identifier: identifier.concat("_").concat(TGSPlatform.getControllerIdentifier(addr))
        )!
    }

    /// Initialize the contract
    ///
    init() {
        let identifier = "TGSPlatform_".concat(self.account.address.toString())
        self.TGSPlatformStoragePath = StoragePath(identifier: identifier)!
        self.TGSPlatformPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
