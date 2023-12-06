// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "PropertyShared"

/// The contract of PropertyComponent
///
pub contract PropertyComponent: TGSComponent {

    /* --- Events --- */

    /// Event that emitted when the property is updated
    ///
    pub event PropertyUpdated(uuid: UInt64, key: String, valueType: String, ownerAddress: Address?)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    pub resource Component: PropertyShared.PropertyComponentPublic, TGSInterfaces.PropertiesHolder, TGSInterfaces.PropertiesSetter, TGSComponent.ComponentBase {
        /* --- Fields --- */
        /// The logger for the component
        ///
        access(contract) var logger: Capability<&AnyResource{TGSLogging.LoggableResource}>?
        /// The property map
        ///
        access(contract) let properties: {String: AnyStruct}

        /* --- Constructor --- */

        /// Constructor
        ///
        init() {
            self.properties = {}
            self.logger = nil
        }

        /* --- Public Methods --- */

        /// Get property item method - PropertyProfilePublic
        ///
        pub fun getPropertyItem(_ key: String): PropertyShared.PropertyItem? {
            if let value = self.getProperty(key) {
                return PropertyShared.PropertyItem(value)
            }
            return nil
        }

        /* --- Private Methods --- */

        /// Set property method
        ///
        pub fun setProperty(_ key: String, _ value: AnyStruct) {
            self.setPropertyRaw(key, value)

            emit PropertyUpdated(
                uuid: self.uuid,
                key: key,
                valueType: value.getType().identifier,
                ownerAddress: self.owner?.address
            )

            // action logging
            if let logger = self.getLogger() {
                logger.log(
                    source: self.getType(),
                    action: "PropComp: setProperty",
                    message: "Key: ".concat(key).concat(" ValueType: ".concat(value.getType().identifier))
                )
            }
        }

        /// Borrow properties dictionary
        /// Open to public for the Resource
        ///
        pub fun borrowProperties(): &{String: AnyStruct} {
            return &self.properties as &{String: AnyStruct}
        }

        /* --- TGSComponent.ComponentBase Implementation --- */

        // Override when nesessery

        /* --- Internal Methods --- */

        // NOTHING
    }

    /// The component factory
    ///
    pub fun create(): @Component {
        let comp <- create Component()
        comp.onInited()
        return <- comp
    }
}
