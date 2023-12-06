// Owned imports
import "TGSInterfaces"
import "TGSLogging"
import "TGSComponent"
import "PropertyShared"
import "PropertyComponent"

/// The contract of PropertyService
///
pub contract PropertyRegistryComponent: TGSComponent {

    /* --- Events --- */

    pub event PropertyRegistered(key: String, type: UInt8, ownerAddress: Address?)
    pub event DynamicPropertyFactorRegistered(key: String, factorType: Type, ownerAddress: Address?)

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// PropertyRegistry resource definition
    ///
    pub resource BasicPropertyRegistry: PropertyShared.PropertyRegistryPublic {
        /// types of properties
        pub let propertyTypes: {String: PropertyShared.PropertyType}

        init() {
            self.propertyTypes = {}
        }

        /* === public methods === */

        pub view fun isPropertyRegistered(_ key: String): Bool {
            return self.propertyTypes[key] != nil
        }

        pub view fun getPropertyKeys(): [String] {
            return self.propertyTypes.keys
        }

        pub view fun getPropertyType(_ key: String): PropertyShared.PropertyType? {
            return self.propertyTypes[key]
        }

        /// Returns the property item from the given component
        /// If the property is not registered or wrong type, it will panic
        ///
        pub fun safeGetPropertyItem(
            _ key: String,
            fromComp: &{PropertyShared.PropertyComponentPublic}
        ): PropertyShared.PropertyItem {
            let item = fromComp.getPropertyItem(key)
                ?? panic("Invalid property")
            if let expectedType = self.getPropertyType(key) {
                PropertyShared.ensurePropertyItemValid(expectedType, item)
            }
            return item
        }

        /* === private methods === */

        pub fun registerPropertyType(_ key: String, _ type: PropertyShared.PropertyType) {
            self.propertyTypes[key] = type
        }
    }

    pub resource interface PropertyRegistryPrivate {
        pub fun registerBasicPropertyType(_ key: String, _ type: PropertyShared.PropertyType)
        pub fun registerDynamicPropertyFactor(_ key: String, _ factor: {PropertyShared.DynamicFactorUnit})
    }

    /// Service resource definition
    ///
    pub resource Component: PropertyShared.PropertyRegistryPublic, PropertyRegistryPrivate, TGSComponent.ComponentBase {
        /// The logger for the component
        access(contract) var logger: Capability<&AnyResource{TGSLogging.LoggableResource}>?

        /// Property registry
        access(self) let basicRegistry: @BasicPropertyRegistry
        access(self) let dynamicPropertyFactors: {String: {PropertyShared.DynamicFactorUnit}}

        init() {
            self.logger = nil
            self.basicRegistry <- create BasicPropertyRegistry()
            self.dynamicPropertyFactors = {}
        }

        destroy() {
            destroy self.basicRegistry
        }

        /* === public methods === */

        pub view fun isPropertyRegistered(_ key: String): Bool {
            return self.dynamicPropertyFactors[key] != nil
        }

        pub view fun getPropertyKeys(): [String] {
            return self.dynamicPropertyFactors.keys
        }

        pub view fun getPropertyType(_ key: String): PropertyShared.PropertyType? {
            if let factor = &self.dynamicPropertyFactors[key] as &{PropertyShared.DynamicFactorUnit}? {
                return factor.resultType(self.borrowBasicRegistry())
            }
            return nil
        }

        /// Returns the property item from the given component
        /// If the property is not registered or wrong type, it will panic
        ///
        pub fun safeGetPropertyItem(
            _ key: String,
            fromComp: &{PropertyShared.PropertyComponentPublic}
        ): PropertyShared.PropertyItem {
            if let factor = (&self.dynamicPropertyFactors[key] as &{PropertyShared.DynamicFactorUnit}?) {
                return factor.execute(self.borrowBasicRegistry(), fromComp: fromComp)
            } else {
                return self.borrowBasicRegistry().safeGetPropertyItem(key, fromComp: fromComp)
            }
        }

        /* === private methods === */

        /// Registers a new basic property type
        ///
        pub fun registerBasicPropertyType(_ key: String, _ type: PropertyShared.PropertyType) {
            pre {
                !self.basicRegistry.isPropertyRegistered(key): "Property already registered"
            }
            self.basicRegistry.registerPropertyType(key, type)

            emit PropertyRegistered(key: key, type: type.rawValue, ownerAddress: self.owner?.address)

            self.getLogger()?.log(
                source: self.getType(),
                action: "PropRegistryComp: registerBasicPropertyType",
                message: "Key: ".concat(key).concat(" Type: ".concat(type.rawValue.toString()))
            )
        }

        /// Registers a new dynamic property factor
        ///
        pub fun registerDynamicPropertyFactor(_ key: String, _ factor: {PropertyShared.DynamicFactorUnit}) {
            self.dynamicPropertyFactors[key] = factor

            emit DynamicPropertyFactorRegistered(key: key, factorType: factor.getType(), ownerAddress: self.owner?.address)

            self.getLogger()?.log(
                source: self.getType(),
                action: "PropRegistryComp: registerDynamicPropertyFactor",
                message: "Key: ".concat(key).concat(" FactorType: ".concat(factor.getType().identifier))
            )
        }

        // === internal methods ===

        access(self) fun borrowBasicRegistry(): &BasicPropertyRegistry {
            return &self.basicRegistry as &BasicPropertyRegistry
        }
    }

    /* --- Methods --- */

    /// The component factory
    ///
    pub fun create(): @Component {
        let comp <- create Component()
        comp.onInited()
        return <- comp
    }
}
