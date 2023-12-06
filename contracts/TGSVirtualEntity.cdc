// Third-party imports
import "MetadataViews"

// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "TGSEntity"

pub contract TGSVirtualEntity: TGSEntity {

    /// The entity resource
    ///
    pub resource Entity: MetadataViews.Resolver, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate {
        /// The components of the entity
        access(contract) let components: @{Type: TGSComponent.Component}
        /// The parent entity
        access(self) var parent: Capability<&AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}>?

        init() {
            self.components <- {}
            self.parent = nil
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
            // NOTHING
        }

        /// Returns the loggable capability
        ///
        access(contract) fun getLoggableCap(): Capability<&AnyResource{TGSLogging.LoggableResource}>? {
            return self.parent
        }

        /** ----  private methods ----  */

        pub fun setParent(_ parent: Capability<&AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}>?) {
            if let parentNotNil = parent {
                assert(parentNotNil.check(), message: "Parent entity must be valid")
                // notify components
                self.activate(parentNotNil)
                // as setLoggableCap is not implemented, we need to set the parent manually
                self.parent = parentNotNil
            } else {
                self.deactivate()
            }
        }

        /* ---- Default implemation of MetadataViews.Resolver ---- */

        /// Returns the types of supported views - none at this time
        ///
        pub fun getViews(): [Type] {
            if let parentRef = self.borrowParent() {
                return parentRef.getViews()
            }
            return []
        }

        /// Resolves the given view if supported - none at this time
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            if let parentRef = self.borrowParent() {
                return parentRef.resolveView(view)
            }
            return nil
        }

        /* ---- Default implemation of TGSLogging.LoggableResource */

        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]? {
            if let parentRef = self.borrowParent() {
                return parentRef.getLogsRef()
            }
            return nil
        }

        /* ---- Internal methods ---- */

        /// Borrow the parent entity
        ///
        access(self) fun borrowParent(): &AnyResource{MetadataViews.Resolver, TGSLogging.LoggableResource}? {
            if let parentCap = self.parent {
                return parentCap.borrow()
            }
            return nil
        }
    }

    /* --- Methods --- */

    pub fun create(): @Entity {
        return <- create Entity()
    }
}
