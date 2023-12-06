// Third-party imports
import "MetadataViews"
import "HybridCustody"

// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSVirtualEntity"

/// The contract interface for TGS Application Service
///
pub contract interface TGSAppService {

    /// The public interface for a service
    ///
    pub resource interface ServiceBlueprintPublic {
        /// Returns the current owner of this service, if there is one
        ///
        pub fun getOwner(): Address?

        /// Returns the identity type of this service
        ///
        pub fun getIdentityType(): Type

        /// Return the storage information of this service
        ///
        pub fun getStorageInfo(): TGSInterfaces.ResourceStorageInfo
    }

    /// The private interface for a service
    ///
    pub resource interface ServiceBlueprintPrivate {
        /// Returns the current owner of this service, if there is one
        ///
        pub fun getOwner(): Address?

        /** Borrow methods */

        /// Returns the auth ref of this service
        ///
        pub fun borrowSelf(): auth &AnyResource{ServiceBlueprintPublic, ServiceBlueprintPrivate}

        /// Returns the current owner of this service
        ///
        access(account) fun borrowAccountManagerAccessor(): &AnyResource{TGSInterfaces.AccountManagerAccessor}?

        /// Returns the account manager capability
        ///
        /// Default implementation is to get the account manager from owner application
        ///
        access(account) fun borrowOwnerAccountManager(): &HybridCustody.Manager{HybridCustody.ManagerPublic, HybridCustody.ManagerPrivate}? {
            if let accessor = self.borrowAccountManagerAccessor() {
                let acmCap = accessor.getAccountManager()
                return acmCap.borrow()
            }
            return nil
        }

        /// Borrow the child account from owner
        /// Can access by any resource which have the capability of ServiceBlueprintPrivate
        ///
        pub fun borrowOwnerChildAccount(child: Address): &{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}? {
            if let acm = self.borrowOwnerAccountManager() {
                return acm.borrowAccount(addr: child)
            }
            return nil
        }

        /** === Lifecycle methods === */

        /// This method is invoked when the service is attached to application
        ///
        pub fun onRegister(_ owner: Capability<&AnyResource{TGSInterfaces.AccountManagerAccessor, MetadataViews.Resolver, TGSLogging.LoggableResource}>) {
            pre {
                owner.check(): "Invalid Application Manager Capability"
            }
            post {
                owner.address == self.getOwner(): "The owner must be set correctly!"
            }
        }
    }

    /// Service resource definition
    ///
    pub resource Service: ServiceBlueprintPublic, ServiceBlueprintPrivate {
        access(account) var ownerApp: Capability<&AnyResource{TGSInterfaces.AccountManagerAccessor, TGSLogging.LoggableResource}>?
        access(account) let virtualEntity: @TGSVirtualEntity.Entity

        /* === public methods === */

        /// Returns the current owner of this service, if there is one
        ///
        pub fun getOwner(): Address? {
            return self.ownerApp?.address
        }

        /// Returns the identity type of this service
        ///
        pub fun getIdentityType(): Type

        /// Return the storage information of this service
        ///
        pub fun getStorageInfo(): TGSInterfaces.ResourceStorageInfo

        /* === private methods: Borrow === */

        /// Returns the auth ref of this service
        ///
        pub fun borrowSelf(): auth &AnyResource{ServiceBlueprintPublic, ServiceBlueprintPrivate} {
            return &self as auth &AnyResource{ServiceBlueprintPublic, ServiceBlueprintPrivate}
        }

        /// Returns the current owner of this service
        ///
        access(account) fun borrowAccountManagerAccessor(): &AnyResource{TGSInterfaces.AccountManagerAccessor}? {
            if let accessor = self.ownerApp?.borrow() {
                return accessor
            }
            return nil
        }

        /** === Lifecycle methods === */

        /// This method is invoked when the service is attached to application
        ///
        pub fun onRegister(_ owner: Capability<&AnyResource{TGSInterfaces.AccountManagerAccessor, MetadataViews.Resolver, TGSLogging.LoggableResource}>) {
            self.ownerApp = owner
            self.virtualEntity.setParent(owner)
        }
    }

    /// Creates an new Service instance and returns it to the caller
    ///
    /// @return A new Service resource
    ///
    pub fun createNewService(): @Service

    /// Returns the identity type of this service
    ///
    pub fun getServiceIdentityType(): Type
}
