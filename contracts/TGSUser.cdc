// Third-party imports
import "MetadataViews"
import "HybridCustody"
import "CapabilityDelegator"

// Owned imports
import "TGSInterfaces"
import "TGSDataCenter"
import "TGSLogging"
import "TGSComponent"
import "TGSEntity"
import "PropertyComponent"
import "TGSAppServiceProfile"

/// The contract for TGS User
///
pub contract TGSUser: TGSEntity {
    /* --- Canonical Paths --- */
    pub let TGSUserStoragePath: StoragePath
    pub let TGSUserPublicPath: PublicPath

    /* --- Events --- */

    pub event ContractInitialized()

    pub event UserCreated(uuid: UInt64, address: Address)
    pub event UserUpsertIdentity(address: Address, platform: String, platformUid: String, name: String?, image: String?)

    pub event ProfileAttached(address: Address, source: Type)
    pub event ProfileRevoked(address: Address, source: Type)

    /* --- Enums and Structs --- */

    pub struct EcosystemIdentity {
        pub let platform: String
        pub let uid: String

        init(_ platform: String, _ uid: String) {
            self.platform = platform
            self.uid = uid
        }
    }

    pub struct ThirdPartyInfo {
        pub let identity: EcosystemIdentity
        pub let display: MetadataViews.Display?

        init(
            _ identity: EcosystemIdentity,
            _ display: MetadataViews.Display?
        ) {
            self.identity = identity
            self.display = display
        }
    }

    /* --- Interfaces & Resources --- */

    /// User public interface
    ///
    pub resource interface UserPublic {
        pub fun isValid(): Bool

        pub fun isPrimary(): Bool
        pub fun getLinkedEcosystems(): [ThirdPartyInfo]
        pub fun getLinkedEcosystemsByPlatform(_ platform: String): ThirdPartyInfo?

        /// Return the public capability
        ///
        pub fun borrowProfilePublic(_ type: Type): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic}?
    }

    /// User private interface
    ///
    pub resource interface UserPrivate {
        /// Update or insert third-party identity
        pub fun upsertIdentity(_ info: ThirdPartyInfo)

        /// Attach the service profile
        ///
        pub fun attachProfileCapability(_ profile: Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>)

        /// Revoke the service profile
        ///
        pub fun revokeProfileCapability(_ source: Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>)

        /// Borrow profile reference by type
        ///
        pub fun borrowProfile(_ type: Type): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}?

        /// Borrow user's property component reference
        ///
        pub fun borrowUserPropertyComponent(): &PropertyComponent.Component
    }

    /// User's borrowable interface
    ///
    pub resource interface BorrowableDelegator {
        /// Returns a reference to the stored delegator
        ///
        pub fun borrowCapabilityDelegator(): &CapabilityDelegator.Delegator?
    }

    /// User resource
    ///
    pub resource Entity: UserPublic, UserPrivate, BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate {
        /// Capability on the underlying account object
        access(self) var acct: Capability<&AuthAccount>
        /// Logging store
        access(self) let logs: [AnyStruct{TGSLogging.LogEntry}]
        /// Logging capability
        access(self) var selfLoggableCap: Capability<&AnyResource{TGSLogging.LoggableResource}>?
        /// Linked third-party ecosystems
        access(self) var linkedEcosystems: {String: ThirdPartyInfo}
        /// Capability delegator
        access(self) let delegator: Capability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>
        /// The components of the entity
        access(contract) let components: @{Type: TGSComponent.Component}

        init(
            _ acctCap: Capability<&AuthAccount>,
        ) {
            self.acct = acctCap
            self.linkedEcosystems = {}
            self.logs = []
            self.selfLoggableCap = nil
            self.components <- {}

            /// ------ initialize capabiltiy delegator ------

            let userAddress = acctCap.address
            let capDelegatorIdentifier = TGSUser.getUserCapabilityDelegatorIdentifier(userAddress)
            let capDelegatorStorage = StoragePath(identifier: capDelegatorIdentifier)!

            let acct = acctCap.borrow() ?? panic("Auth account not exists")
            assert(
                acct.borrow<&AnyResource>(from: capDelegatorStorage) == nil,
                message: "conflicting resource found in capability delegator storage slot for user"
            )
            if acct.borrow<&CapabilityDelegator.Delegator>(from: capDelegatorStorage) == nil {
                let delegator <- CapabilityDelegator.createDelegator()
                acct.save(<-delegator, to: capDelegatorStorage)
            }

            // issue public capability
            let pubCap = acct
                .capabilities.storage
                .issue<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic}>(capDelegatorStorage)
            // publish to public path
            acct.capabilities.publish(pubCap, at: PublicPath(identifier: capDelegatorIdentifier)!)

            // issue private capability
            let delegator: Capability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}> = acct
                .capabilities.storage
                .issue<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>(capDelegatorStorage)
            assert(delegator.check(), message: "failed to issue capability delegator for user")
            // set delegator capability
            self.delegator = delegator

            // initialize the entity

            // Attach the property component
            self.attachComponent(<- PropertyComponent.create())
        }

        destroy() {
            for k in self.components.keys {
                self.components[k]?.beforeDestory()
            }
            destroy self.components
        }

        /// Initialize the TGSUser
        ///
        pub fun initialize() {
            pre {
                !self.isActive(): "TGSUser is already initialized"
            }
            // ensure owner exisrs
            self.getOwnerAddress()

            // issue the publish cap
            self.issueAndPublishPublicCapablity()
            // issue loggable capability, and initialize the entity
            self.activate(self.issueLoggableCapability())

            // action logging
            self.log(
                source: self.getType(),
                action: "initialize",
                message: "Address: ".concat(self.getOwnerAddress().toString())
            )
        }

        /* === public implementation === */

        /// Get the linked third-party ecosystems
        ///
        pub fun getLinkedEcosystems(): [ThirdPartyInfo] {
            return self.linkedEcosystems.values
        }

        /// Get the linked third-party ecosystems by platform
        ///
        pub fun getLinkedEcosystemsByPlatform(_ platform: String): ThirdPartyInfo? {
            return self.linkedEcosystems[platform]
        }

        /// Is the user valid
        ///
        pub fun isValid(): Bool {
            return self.getOwnerAddress() == self.acct.address
        }

        /// Check if the user is primary
        ///
        pub fun isPrimary(): Bool {
            let primaryPlatfromKey = TGSDataCenter.getPrimaryPlatfromKey()
            return self.linkedEcosystems[primaryPlatfromKey] != nil
        }

        /// Return the profile public reference
        ///
        pub fun borrowProfilePublic(_ type: Type): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic}? {
            if let delegator = self.borrowCapabilityDelegator() {
                if let cap = delegator.getPublicCapability(type) {
                    if let c = cap as? Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic}> {
                        return c.borrow()
                    }
                }
            }
            return nil
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

        /* ---- implemation of TGSLogging.LoggableResource */

        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]? {
            return &self.logs as &[AnyStruct{TGSLogging.LogEntry}]
        }

        /* === private methods === */

        /// Checks the validity of the encapsulated account Capability
        ///
        pub fun check(): Bool {
            return self.acct.check()
        }

        /// Returns a reference to the encapsulated account object
        ///
        access(contract) fun borrowAccount(): &AuthAccount {
            return self.acct.borrow()!
        }

        /// Upsert the third-party identity
        ///
        pub fun upsertIdentity(_ info: ThirdPartyInfo) {
            let profileAddr = self.owner?.address ?? panic("Owner not exists")
            let platform = info.identity.platform
            let platformUid = info.identity.uid

            let dataCenter = TGSDataCenter.borrowDataCenterInternal()
            let existedAddress = dataCenter.getAddressByThirdpartyUid(platform, platformUid)
            assert(
                existedAddress == nil || existedAddress == profileAddr,
                message: "Platfrom UID has been already registered."
            )

            if existedAddress == nil {
                dataCenter.setThirdpartyUid(platform, platformUid, profileAddr)
            }

            self.linkedEcosystems[platform] = info

            // Emit event
            emit UserUpsertIdentity(
                address: profileAddr,
                platform: platform,
                platformUid: platformUid,
                name: info.display?.name,
                image: info.display?.thumbnail?.uri()
            )

            // action logging
            self.log(
                source: self.getType(),
                action: "upsertIdentity",
                message: "Platform - ".concat(platformUid)
            )
        }

        /// Returns a reference to the stored delegator
        ///
        pub fun borrowCapabilityDelegator(): &CapabilityDelegator.Delegator? {
            let path = TGSUser.getUserCapabilityDelegatorIdentifier(self.getOwnerAddress())
            return self.borrowAccount().borrow<&CapabilityDelegator.Delegator>(
                from: StoragePath(identifier: path)!
            )
        }

        /// Borrow profile's private property component reference
        ///
        pub fun borrowUserPropertyComponent(): &PropertyComponent.Component {
            let comp = self.borrowComponent(Type<@PropertyComponent.Component>())
            return comp as? &PropertyComponent.Component
                ?? panic("Failed to load property component")
        }

        /// Return the profile private reference
        ///
        pub fun borrowProfile(_ type: Type): &AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}? {
            if let delegator = self.borrowCapabilityDelegator() {
                if let cap = delegator.getPrivateCapability(type) {
                    if let c = cap as? Capability<&AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}> {
                        return c.borrow()
                    }
                }
            }
            return nil
        }

        /// Attach the service profile
        ///
        pub fun attachProfileCapability(_ profile: Capability<&{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>) {
            let delegatorRef = self.borrowCapabilityDelegator() ?? panic("Failed to load delegator")

            assert(
                delegatorRef.getPrivateCapability(profile.getType()) == nil,
                message: "The private capability already exists"
            )
            assert(profile.check(), message: "profile capability is invalid")

            // add capability
            delegatorRef.addCapability(cap: profile, isPublic: false)

            let loggableCap = self.issueLoggableCapability()

            let profileRef = profile.borrow()!
            profileRef.setParent(loggableCap)

            emit ProfileAttached(
                address: self.getOwnerAddress(),
                source: profileRef.getType()
            )

            // action logging
            self.log(
                source: self.getType(),
                action: "attachProfileCapability",
                message: "Profile Identifier".concat(profileRef.getType().identifier)
            )
        }

        /// Revoke the service profile
        ///
        pub fun revokeProfileCapability(_ source: Capability<&{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}>) {
            let delegatorRef = self.borrowCapabilityDelegator() ?? panic("Failed to load delegator")
            let capType = source.getType()

            assert(source.check(), message: "The capability is invalid")
            // remove capability
            delegatorRef.removeCapability(cap: source)

            let ref = source.borrow()!
            ref.setParent(nil)

            emit ProfileRevoked(
                address: self.owner?.address ?? panic("Owner not exists"),
                source: ref.getType()
            )

            // action logging
            self.log(
                source: self.getType(),
                action: "revokeProfileCapability",
                message: "Profile Identifier".concat(ref.getType().identifier)
            )
        }

        /* === private internal methods === */

        /// Issue a new loggable capability
        ///
        access(self) fun issueLoggableCapability(): Capability<&AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}> {
            post {
                result.check(): "Invalid loggable capability"
            }
            let acct = self.acct.borrow() ?? panic("Auth account not exists")
            return acct.capabilities.storage
                .issue<&Entity{MetadataViews.Resolver, TGSLogging.LoggableResource}>(TGSUser.TGSUserStoragePath)
        }

        /// Issue and publish the new public capability
        ///
        access(self) fun issueAndPublishPublicCapablity() {
            let acct = self.acct.borrow() ?? panic("Auth account not exists")
            if acct.capabilities.get<&AnyResource>(TGSUser.TGSUserPublicPath) != nil {
                acct.capabilities.unpublish(TGSUser.TGSUserPublicPath)
            }
            // issue public capability
            let userPubCap = acct
                .capabilities.storage
                .issue<&Entity{UserPublic}>(TGSUser.TGSUserStoragePath)
            assert(userPubCap.check(), message: "Invalid user public capability")
            // public public capability
            acct.capabilities.publish(userPubCap, at: TGSUser.TGSUserPublicPath)
        }

        /// Issue the user private capability
        ///
        access(account) fun issueUserPrivCap(): Capability<&Entity{UserPublic, UserPrivate, BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}> {
            post {
                result.check(): "Invalid user private capability"
            }

            let acct = self.acct.borrow() ?? panic("Auth account not exists")
            let cap = acct
                .capabilities.storage
                .issue<&Entity{UserPublic, UserPrivate, BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}>
                (TGSUser.TGSUserStoragePath)
            return cap
        }
    }

    /* --- Methods --- */

    /// Utility function to get the user resource identifier
    ///
    pub fun getUserCapabilityDelegatorIdentifier(_ addr: Address): String {
        return "UserCapabilityDelegator_".concat(addr.toString())
    }

    /// Get user address by platform uid
    ///
    pub fun getUserAddressByPlatfromUid(_ platform: String, _ uid: String): Address? {
        let dataCenter = TGSDataCenter.borrowDataCenter()
        return dataCenter.getAddressByThirdpartyUid(platform, uid)
    }

    /// Create the user resource
    ///
    pub fun createUser(
        _ acctCap: Capability<&AuthAccount>
    ) {
        pre {
            acctCap.check(): "invalid auth account capability"
        }
        let userAddress = acctCap.borrow()!.address
        let acct = acctCap.borrow() ?? panic("Auth account not exists")

        // Check if the user already exists
        assert(
            acct.borrow<&AnyResource>(from: self.TGSUserStoragePath) == nil,
            message: "user already exists"
        )

        // create the user with capability delegator
        let user <- create Entity(acctCap)
        let userUid = user.uuid
        acct.save(<- user, to: self.TGSUserStoragePath)

        let userRef = acct.borrow<&TGSUser.Entity>(from: self.TGSUserStoragePath)
            ?? panic("Failed to borrow user reference")
        userRef.initialize()

        emit UserCreated(uuid: userUid, address: userAddress)
    }

    /// Get the user resource's public capability
    ///
    pub fun getUserPublicCapability(_ addr: Address): Capability<&Entity{UserPublic}>? {
        return getAccount(addr)
            .capabilities
            .get<&Entity{UserPublic}>(self.TGSUserPublicPath)
    }

    /// Returns the user private capability type
    ///
    pub fun getUserPrivateCapabilityType(): Type {
        return Type<Capability<&Entity{UserPublic, UserPrivate, BorrowableDelegator, HybridCustody.BorrowableAccount, MetadataViews.Resolver}>>()
    }

    /// Initialize the contract
    ///
    init() {
        let identifier = "TGSUser_".concat(self.account.address.toString())
        self.TGSUserStoragePath = StoragePath(identifier: identifier)!
        self.TGSUserPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
