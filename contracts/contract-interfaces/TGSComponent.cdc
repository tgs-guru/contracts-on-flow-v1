// Owned imports
import "TGSLogging"

/// The contract interface for the component resource
///
pub contract interface TGSComponent {

    /// The private interface for a Component
    ///
    pub resource interface ComponentBase {
        // ===== Private Methods =====

        /// Returns if the component is attached to some loggable entity.
        ///
        pub fun isAttached(): Bool

        /// Returns the loggable entity
        ///
        pub fun getLogger(): &AnyResource{TGSLogging.LoggableResource}?

        // ====== Life cycle Methods ======

        /// This method is invoked when the blueprint is created
        /// When calling this method, the owner is a shared data center resource
        pub fun onInited() {
            return
        }

        /// This method is invoked when the blueprint is attached to owner resource
        /// When calling this method, the owner has been set.
        ///
        pub fun onAttached(loggable: Capability<&AnyResource{TGSLogging.LoggableResource}>) {
            pre {
                loggable.check(): "Invalid Loggable Capability"
            }
        }

        /// This method is invoked when the blueprint is detached from owner resource
        /// When calling this method, the owner has been set to null.
        ///
        pub fun onDetached() {
            return
        }

        /// This method is invoked when the blueprint is destroyed
        ///
        pub fun beforeDestory() {
            return
        }
    }

    /* --- Interfaces & Resources --- */
    pub resource Component: ComponentBase {
        access(contract) var logger: Capability<&AnyResource{TGSLogging.LoggableResource}>?

        /// Returns if the profile is attached to the TGSUser Account
        ///
        pub fun isAttached(): Bool {
            return self.logger != nil
        }

        /// Returns the loggable entity
        ///
        pub fun getLogger(): &AnyResource{TGSLogging.LoggableResource}? {
            if let logger = self.logger?.borrow() {
                return logger
            }
            return nil
        }

        // ====== Life cycle Methods ======

        /// This method is invoked when the blueprint is created
        /// When calling this method, the owner is a shared data center resource
        pub fun onInited() {
            return
        }

        /// This method is invoked when the blueprint is attached to owner resource
        /// When calling this method, the owner has been set.
        ///
        pub fun onAttached(loggable: Capability<&AnyResource{TGSLogging.LoggableResource}>) {
            self.logger = loggable
        }

        /// This method is invoked when the blueprint is detached from owner resource
        /// When calling this method, the owner has been set to null.
        ///
        pub fun onDetached() {
            self.logger = nil
        }

        /// This method is invoked when the blueprint is destroyed
        ///
        pub fun beforeDestory() {
            return
        }
    }

    /// The component factory
    ///
    pub fun create(): @Component
}
