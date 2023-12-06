// Third-party imports
import "MetadataViews"

// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "TGSAppService"
import "TGSAppServiceProfile"
import "TGSVirtualEntity"
import "PropertyShared"
import "PropertyComponent"
import "PropertyRegistryComponent"
import "PropertyProfile"

/// The contract of PropertyService
///
pub contract PropertyService: TGSAppService {

    /* --- Events --- */

    pub event PropertyProviderInitialized(name: String, ownerAddress: Address?)

    pub event ServicePropertyUpdated(key: String, valueType: Type)
    pub event UserPropertyUpdated(provider: String, profileId: UInt64, key: String, valueType: Type)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// Public interface of PropertyService
    ///
    pub resource interface PropertyServicePublic {
        /// Get the property keys
        ///   -- registry: the name of the property registry
        pub view fun getPropertyKeys(registry: String): [String]
        /// Get the property type
        ///   -- registry: the name of the property registry
        ///   -- key: the property key
        pub view fun getPropertyType(registry: String, key: String): PropertyShared.PropertyType?
        /// Borrow the public reference of the property registry
        ///   -- name: the name of the property registry
        pub fun borrowPropertyRegistryPublic(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic}?
        /// Borrow the public reference of the property component
        pub fun borrowServicePropertyComponentPublic(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder}
        /// Get the property value of the service
        ///   -- key: the property key
        pub fun safeGetServiceProperty(key: String): PropertyShared.PropertyItem
        /// Get the property value of the profile
        ///   -- registry: the name of the property registry
        ///   -- key: the property key
        ///   -- profile: the user profile
        pub fun safeGetProfileProperties(registry: String, keys: [String], profile: &{PropertyProfile.PropertyProfilePublic}): [PropertyShared.PropertyItem]
        /// Get the property value of the user
        ///   -- registry: the name of the property registry
        ///   -- key: the property key
        ///   -- fromUser: the user address
        pub fun safeGetUserProperty(registry: String, key: String, fromUser: Address): PropertyShared.PropertyItem
        /// Get the properties value of the user
        ///   -- name: the name of the property registry
        ///   -- keys: the property keys
        ///   -- fromUser: the user address
        pub fun safeGetUserProperties(registry: String, keys: [String], fromUser: Address): [PropertyShared.PropertyItem]
    }

    /// Private interface of PropertyService
    ///
    pub resource interface PropertyServicePrivate {
        /// Initialize a new property registry
        ///   -- name: the name of the property registry
        pub fun initializePropertyRegistry(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic, PropertyRegistryComponent.PropertyRegistryPrivate, TGSComponent.ComponentBase}
        /// Borrow the private reference of the property registry
        ///   -- name: the name of the property registry
        pub fun borrowPropertyRegistry(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic, PropertyRegistryComponent.PropertyRegistryPrivate, TGSComponent.ComponentBase}?
        /// Borrow the private reference of the service property component
        pub fun borrowServicePropertyComponent(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter, TGSComponent.ComponentBase}
        /// Set the property value of the service
        pub fun setServiceProperty(key: String, value: AnyStruct)
        /// Set the property's value
        ///   -- registry: the name of the property registry
        pub fun setUserProperty(registry: String, user: Address, key: String, value: AnyStruct)
        /// Set the property's value
        ///   -- registry: the name of the property registry
        pub fun setProfileProperty(registry: String, profile: &{PropertyProfile.PropertyProfilePrivate}, key: String, value: AnyStruct)
    }

    /// Service resource definition
    ///
    pub resource Service: PropertyServicePublic, PropertyServicePrivate, TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate, TGSAppServiceProfile.ServiceBlueprintWithProfile {
        // The owner application of this service
        access(account) var ownerApp: Capability<&AnyResource{TGSInterfaces.AccountManagerAccessor, TGSLogging.LoggableResource}>?
        access(account) let virtualEntity: @TGSVirtualEntity.Entity
        // provider resources
        access(self) let providers: @{String: TGSVirtualEntity.Entity}

        init() {
            self.ownerApp = nil
            self.providers <- {}
            self.virtualEntity <- TGSVirtualEntity.create()
            self.virtualEntity.attachComponent(<- PropertyComponent.create())
        }

        destroy() {
            destroy self.virtualEntity
            destroy self.providers
        }

        /* === public methods === */

        /// Returns the identity type of this service
        ///
        pub fun getIdentityType(): Type {
            return PropertyService.getServiceIdentityType()
        }

        /// Return the storage information of this service
        ///
        pub fun getStorageInfo(): TGSInterfaces.ResourceStorageInfo {
            return PropertyService.getStorageInfo()
        }

        /// Borrow the public reference of the property registry
        ///
        pub fun borrowPropertyRegistryPublic(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic}? {
            return self.borrowPropertyRegistry(name: name)
        }

        /// Get the property keys
        ///
        pub view fun getPropertyKeys(registry: String): [String] {
            let provider = self.borrowPropertyRegistry(name: registry)
                ?? panic("Failed to get the property registry.")
            return provider.getPropertyKeys()
        }

        /// Get the property type
        ///
        pub view fun getPropertyType(registry: String, key: String): PropertyShared.PropertyType? {
            let provider = self.borrowPropertyRegistry(name: registry)
                ?? panic("Failed to get the property registry.")
            return provider.getPropertyType(key)
        }

        /// Get the property value
        ///
        pub fun safeGetUserProperty(registry: String, key: String, fromUser: Address): PropertyShared.PropertyItem {
            return self.safeGetUserProperties(registry: registry, keys: [key], fromUser: fromUser)[0]
        }

        /// Get the properties value
        ///
        pub fun safeGetUserProperties(registry: String, keys: [String], fromUser: Address): [PropertyShared.PropertyItem] {
            // check dependences for the user
            if let profileRef = self.borrowUserPropertyProfile(user: fromUser) {
                return self.safeGetProfileProperties(registry: registry, keys: keys, profile: profileRef)
            } // end of if
            panic("Failed to get the properties")
        }

        /// Get the property value of the profile
        ///   -- name: the name of the property registry
        ///   -- key: the property key
        ///   -- profile: the user profile
        pub fun safeGetProfileProperties(registry: String, keys: [String], profile: &{PropertyProfile.PropertyProfilePublic}): [PropertyShared.PropertyItem] {
            // the property list
            let list:[PropertyShared.PropertyItem] = []

            // get the property registry
            let provider = self.borrowPropertyRegistry(name: registry)
                ?? panic("Failed to get the property registry.")

            // we get the property component from the user
            let propertyComp = profile.borrowPropertyComponentPublic()
            // now we can get the property value from the provider
            for key in keys {
                list.append(
                    provider.safeGetPropertyItem(key, fromComp: propertyComp)
                )
            }
            return list
        }

        /// Borrow the public reference of the property component
        ///
        pub fun borrowServicePropertyComponentPublic(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder} {
            return self.borrowServicePropertyComponent()
        }

        /// Get the property value of the service
        ///
        pub fun safeGetServiceProperty(key: String): PropertyShared.PropertyItem {
            let propertyComp = self.borrowServicePropertyComponent()
            return propertyComp.getPropertyItem(key) ?? panic("Failed to get the property.")
        }

        /** === private methods: TGSAppService related(override) === */

        /// This method is invoked when the service is attached to application
        ///
        pub fun onRegister(_ owner: Capability<&AnyResource{TGSInterfaces.AccountManagerAccessor, MetadataViews.Resolver, TGSLogging.LoggableResource}>) {
            self.ownerApp = owner
            self.virtualEntity.activate(owner)
            for name in self.providers.keys {
                self.providers[name]?.activate(owner)
            }
        }

        /* === private methods: profile related === */

        /// Initialize a new property registry
        ///
        pub fun initializePropertyRegistry(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic, PropertyRegistryComponent.PropertyRegistryPrivate, TGSComponent.ComponentBase} {
            pre {
                self.ownerApp != nil: "The service is not attached to any application."
                self.providers[name] == nil: "The property registry already exists."
            }

            let entity <- TGSVirtualEntity.create()
            entity.attachComponent(<- PropertyRegistryComponent.create())
            self.providers[name] <-! entity
            // activate entity
            self.providers[name]?.activate(self.ownerApp!)

            emit PropertyProviderInitialized(
                name: name,
                ownerAddress: self.getOwner()
            )

            return self.borrowPropertyRegistry(name: name)
                ?? panic("Failed to get the property registry.")
        }

        /// Borrow the private reference of the property registry
        ///
        pub fun borrowPropertyRegistry(name: String): &PropertyRegistryComponent.Component{PropertyShared.PropertyRegistryPublic, PropertyRegistryComponent.PropertyRegistryPrivate, TGSComponent.ComponentBase}? {
            if let entityRef = &self.providers[name] as &TGSVirtualEntity.Entity? {
                if let comp = entityRef.borrowComponent(Type<@PropertyRegistryComponent.Component>()) {
                    return comp as! &PropertyRegistryComponent.Component
                }
            } else if name == "default" {
                // create default property registry
                return self.initializePropertyRegistry(name: name)
            }
            return nil
        }

        /// Set the property's value
        ///
        pub fun setUserProperty(registry: String, user: Address, key: String, value: AnyStruct) {
            // borrow profile ref
            let userProfileRef = self.borrowUserPropertyProfile(user: user)
                ?? panic("Failed to get the user profile.")
            self.setProfileProperty(registry: registry, profile: userProfileRef, key: key, value: value)
        }

        /// Set the property's value
        ///   -- registry: the name of the property registry
        pub fun setProfileProperty(registry: String, profile: &{PropertyProfile.PropertyProfilePrivate}, key: String, value: AnyStruct) {
            // borrow provider ref
            let provider = self.borrowPropertyRegistry(name: registry)
                ?? panic("Failed to get the property registry.")
            // get the property component
            if let expectedType = provider.getPropertyType(key) {
                PropertyShared.ensurePropertyItemValid(expectedType, PropertyShared.PropertyItem(value))
            }
            // set property
            profile.borrowPropertyComponent().setProperty(key, value)

            emit UserPropertyUpdated(
                provider: registry,
                profileId: profile.uuid,
                key: key,
                valueType: value.getType()
            )
        }

        /// Borrow the private reference of the service property component
        ///
        pub fun borrowServicePropertyComponent(): &PropertyComponent.Component{PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter, TGSComponent.ComponentBase} {
            let propCompType = Type<@PropertyComponent.Component>()
            let comp = self.virtualEntity.borrowComponent(propCompType)
                ?? panic("Cannot borrow the property component")
            return comp as! &PropertyComponent.Component
        }

        /// Set the properties' value
        ///
        pub fun setServiceProperty(key: String, value: AnyStruct) {
            let propComp = self.borrowServicePropertyComponent()
            propComp.setProperty(key, value)

            emit ServicePropertyUpdated(
                key: key,
                valueType: value.getType()
            )
        }

        /// Returns the profile resource based on the platform and uid
        ///
        pub fun generateProfile(
            _ options: {String: AnyStruct}
        ): @AnyResource{TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv} {
            pre {
                self.getOwner() != nil: "OwnerApp doesn't exist."
            }
            return <- PropertyProfile.createProfile(self.getOwner()!, self.getIdentityType())
        }

        /// Return the storage information of this profile resource
        ///
        pub fun getProfileStorageInfo(): TGSInterfaces.ResourceStorageInfo {
            return PropertyProfile.getStorageInfo()
        }

        // === internal methods ===

        /// Borrow the private reference of the property profile
        ///
        access(self) fun borrowUserPropertyProfile(
            user: Address
        ): &PropertyProfile.Profile{PropertyProfile.PropertyProfilePublic, PropertyProfile.PropertyProfilePrivate, TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}? {
            // check dependences for the user
            if let childAccount = self.borrowOwnerChildAccount(child: user) {
                // Get capability type of the property profile
                let info = self.getProfileStorageInfo()
                let cap = childAccount.getPrivateCapFromDelegator(type: info.privateCapabilityType)
                if let profileCap = cap as? Capability<&PropertyProfile.Profile{PropertyProfile.PropertyProfilePublic, PropertyProfile.PropertyProfilePrivate, TGSAppServiceProfile.ProfileBlueprintPublic, TGSAppServiceProfile.ProfileBlueprintPriv}> {
                    // borrow the profile from the capability
                    return profileCap.borrow()
                }
            } // end of if
            return nil
        }
    }

    /* --- Methods --- */

    /// Returns the storage information of this contract
    ///
    pub fun getStorageInfo(): TGSInterfaces.ResourceStorageInfo {
        let identifier = "PropertyService_".concat(self.account.address.toString())
        return TGSInterfaces.ResourceStorageInfo(
            storagePath: StoragePath(identifier: identifier)!,
            publicPath: PublicPath(identifier: identifier)!,
            publicCapabilityType: Type<Capability<&Service{PropertyServicePublic, TGSAppService.ServiceBlueprintPublic}>>(),
            privateCapabilityType: Type<Capability<&Service{PropertyServicePublic, PropertyServicePrivate, TGSAppService.ServiceBlueprintPublic, TGSAppService.ServiceBlueprintPrivate, TGSAppServiceProfile.ServiceBlueprintWithProfile}>>()
        )
    }

    /// Returns the identity type of this service
    ///
    pub fun getServiceIdentityType(): Type {
        return Type<@Service>()
    }

    /// Creates an new Service instance and returns it to the caller
    ///
    /// @return A new Service resource
    ///
    pub fun createNewService(): @Service {
        return <- create Service()
    }
}
