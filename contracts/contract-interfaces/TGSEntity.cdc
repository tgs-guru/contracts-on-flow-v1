// Third-party imports
import "MetadataViews"

// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"

/// The contract interface for the entity resource
///
pub contract interface TGSEntity {

    /* --- Interfaces & Resources --- */

    /// The public interface for the entity resource
    ///
    pub resource interface EntityPublic {
        /// Return owner address
        pub fun getOwnerAddress(): Address {
            return self.owner?.address ?? panic("Invalid owner address")
        }
        /// Returns true if the entity is active
        pub fun isActive(): Bool
        /// Returns true if the entity has a component of the given type
        pub fun hasComponent(_ type: Type): Bool
        /// Returns the components' types
        pub fun getComponetKeys(): [Type]
    }

    /// The private interface for the entity resource
    ///
    pub resource interface EntityPrivate {
        /// Attaches the given component to the entity
        pub fun attachComponent(_ component: @TGSComponent.Component)
        /// Detaches the component of the given type from the entity
        pub fun detachComponent(_ componentType: Type): @TGSComponent.Component
        /// Borrows the component of the given type from the entity
        pub fun borrowComponent(_ componentType: Type): auth &TGSComponent.Component?
    }

    /// The entity resource
    ///
    pub resource Entity: MetadataViews.Resolver, TGSLogging.LoggableResource, EntityPublic, EntityPrivate {
        /// The components of the entity
        access(contract) let components: @{Type: TGSComponent.Component}

        /// Activate the entity, resource method
        /// - Parameter loggable: self capability of the loggable resource
        ///
        pub fun activate(
            _ loggable: Capability<&AnyResource{TGSLogging.LoggableResource}>
        ) {
            pre {
                self.getLoggableCap() == nil: "Entity already activated"
                self.getOwnerAddress() == loggable.address: "Loggable must be the owner"
                loggable.check(): "Invalid Loggable Capability"
            }
            /// set up loggable capablity
            self.setLoggableCap(loggable)
            /// attach all components to laggable
            for k in self.components.keys {
                self.components[k]?.onAttached(loggable: loggable)
            }
        }

        /// Deactivate the entity, resource method
        ///
        pub fun deactivate() {
            pre {
                self.getLoggableCap() != nil: "Entity not activated"
            }
            self.setLoggableCap(nil)
            /// detach all components to laggable
            for k in self.components.keys {
                self.components[k]?.onDetached()
            }
        }

        /// ----- Loggable capability -----

        /// Sets the loggable capability
        ///
        access(contract) fun setLoggableCap(_ loggable: Capability<&AnyResource{TGSLogging.LoggableResource}>?)

        /// Returns the loggable capability
        ///
        access(contract) fun getLoggableCap(): Capability<&AnyResource{TGSLogging.LoggableResource}>?

        /* ---- Default implemation of TGSLogging.LoggableResource */

        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]?

        /* ---- Default implemation of MetadataViews.Resolver ---- */

        /// Returns the types of supported views - none at this time
        ///
        pub fun getViews(): [Type] {
            return []
        }

        /// Resolves the given view if supported - none at this time
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }

        /* ----- Default implementation of Entity Public */

        /// Returns true if the entity is active
        ///
        pub fun isActive(): Bool {
            return self.getLoggableCap() != nil
        }

        /// Returns true if the entity has a component of the given type
        ///
        pub fun hasComponent(_ type: Type): Bool {
            return self.components.containsKey(type)
        }

        /// Returns the components' types
        ///
        pub fun getComponetKeys(): [Type] {
            return self.components.keys
        }

        /* ----- Default implementation of Entity Private */

        /// Attaches the given component to the entity
        ///
        pub fun attachComponent(_ component: @TGSComponent.Component) {
            let type = component.getType()
            assert(
                self.components[type] == nil,
                message: "This component already attached to entity"
            )
            self.components[type] <-! component
            if let loggable = self.getLoggableCap() {
                self.components[type]?.onAttached(loggable: loggable)
            }
        }

        /// Detaches the component of the given type from the entity
        ///
        pub fun detachComponent(_ componentType: Type): @TGSComponent.Component {
            let comp <- (self.components.remove(key: componentType) ?? panic("This component is not attached to entity"))
            comp.onDetached()
            return <- comp
        }

        /// Borrows the component of the given type from the entity
        ///
        pub fun borrowComponent(_ componentType: Type): auth &TGSComponent.Component? {
            return &self.components[componentType] as auth &TGSComponent.Component?
        }
    }
}
