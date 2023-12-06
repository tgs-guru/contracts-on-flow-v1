/// SPDX-License-Identifier: MIT
// Owned imports
import "TGSInterfaces"

/// The contract of PropertyShared
///
pub contract PropertyShared {

    /* --- Interfaces & Resources --- */

    /// Public interface of PropertyProfile
    ///
    pub resource interface PropertyComponentPublic {
        pub fun getPropertyItem(_ key: String): PropertyItem?
    }

    /// Public interface of PropertyRegistry
    ///
    pub resource interface PropertyRegistryPublic {
        pub view fun getPropertyKeys(): [String]
        pub view fun isPropertyRegistered(_ key: String): Bool
        pub view fun getPropertyType(_ key: String): PropertyType?

        /// Get the property item of the given key in a safe way
        /// If the value is invalid, it will throw an error
        ///
        pub fun safeGetPropertyItem(_ key: String, fromComp: &{PropertyComponentPublic}): PropertyItem
    }

    /* --- Enums and Structs --- */

    /// Enum for property type
    ///
    pub enum PropertyType: UInt8 {
        pub case Boolean
        pub case String
        pub case NumericInt64
        pub case NumericUInt64
        pub case NumericFix64
        pub case NumericUFix64
        pub case NumericPercentage // Value: UFix64, 100 = 100%
    }

    /// Property item struct
    ///
    pub struct PropertyItem {
        access(contract)
        let value: AnyStruct

        init (_ value: AnyStruct) {
            self.value = value
        }

        pub fun asFix64(): Fix64? {
            return self.value as? Fix64
        }
        pub fun asUFix64(): UFix64? {
            return self.value as? UFix64
        }
        pub fun asInt(): Int? {
            return self.value as? Int
        }
        pub fun asUInt(): UInt? {
            return self.value as? UInt
        }
        pub fun asUInt64(): UInt64? {
            return self.value as? UInt64
        }
        pub fun asInt64(): Int64? {
            return self.value as? Int64
        }
        pub fun asAddress(): Address? {
            return self.value as? Address
        }
        pub fun asString(): String? {
            return self.value as? String
        }
        pub fun asBool(): Bool? {
            return self.value as? Bool
        }

        /// Add operator, self + other -> newItem
        ///
        pub fun plus(_ other: PropertyItem): PropertyItem {
            pre {
                self.value.getType() == other.value.getType(): "PropertyItem - plus: Types are not equal"
            }
            post {
                self.value.getType() == result.value.getType(): "PropertyItem - plus: return type are not equal"
            }
            if let val = self.asFix64() {
                return PropertyItem(val + other.asFix64()!)
            } else if let val = self.asUFix64() {
                return PropertyItem(val + other.asUFix64()!)
            } else if let val = self.asInt() {
                return PropertyItem(val + other.asInt()!)
            } else if let val = self.asUInt() {
                return PropertyItem(val + other.asUInt()!)
            } else if let val = self.asUInt64() {
                return PropertyItem(val + other.asUInt64()!)
            } else if let val = self.asInt64() {
                return PropertyItem(val + other.asInt64()!)
            } else if let val = self.asString() {
                return PropertyItem(val.concat(other.asString()!))
            }
            panic("Unsupported type for plus method")
        }

        /// Multiply operator, self x other -> newItem
        ///
        pub fun multiply(_ other: PropertyItem): PropertyItem {
            pre {
                self.value.getType() == other.value.getType(): "PropertyItem - multiply: Types are not equal"
            }
            post {
                self.value.getType() == result.value.getType(): "PropertyItem - multiply: return type are not equal"
            }
            if let val = self.asFix64() {
                return PropertyItem(val * other.asFix64()!)
            } else if let val = self.asUFix64() {
                return PropertyItem(val * other.asUFix64()!)
            } else if let val = self.asInt() {
                return PropertyItem(val * other.asInt()!)
            } else if let val = self.asUInt() {
                return PropertyItem(val * other.asUInt()!)
            } else if let val = self.asUInt64() {
                return PropertyItem(val * other.asUInt64()!)
            } else if let val = self.asInt64() {
                return PropertyItem(val * other.asInt64()!)
            }
            panic("Unsupported type for multiply method")
        }
    }

    /// Dynamic Property Factor definition
    ///
    pub struct interface DynamicFactorUnit {
        /// The property type of this unit
        ///
        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType

        /// Executes the factor unit and returns the result
        ///
        pub fun execute(_ registry: &{PropertyRegistryPublic}, fromComp: &{PropertyComponentPublic}): PropertyItem
    }

    pub struct interface DynamicFactorUnitWithChildren {
        access(contract)
        var children: [{DynamicFactorUnit}]

        /// The property type of this unit
        ///
        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType

        /// Setup the children of the Factor
        ///
        pub fun setChildren(
            _ registry: &{PropertyRegistryPublic},
            children: [{DynamicFactorUnit}]
        ) {
            let selfResultType = self.resultType(registry)
            for one in children {
                assert(one.resultType(registry) == selfResultType, message: "Invalid factor type of the child")
            }
            self.children = children
        }
    }

    /// Dynamic Property Factor definition
    ///
    pub struct ValueFactorUnit: DynamicFactorUnit {
        pub let key: String

        init(_ key: String) {
            self.key = key
        }

        /** ---- Implement DynamicFactorUnit ---- **/

        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType {
            return registry.getPropertyType(self.key) ?? panic("Invalid property key")
        }

        pub fun execute(_ registry: &{PropertyRegistryPublic}, fromComp: &{PropertyComponentPublic}): PropertyItem {
            return registry.safeGetPropertyItem(self.key, fromComp: fromComp)
        }
    }

    /// Dynamic Property Factor - convert to Fix64 or UFix64
    ///
    pub struct Fix64ConvertorFactorUnit: DynamicFactorUnit {
        pub let source: {DynamicFactorUnit}

        init(_ source: {DynamicFactorUnit}) {
            self.source = source
        }

        /** ---- Implement DynamicFactorUnit ---- **/

        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType {
            pre {
                self.source.resultType(registry) != PropertyType.Boolean: "Invalid factor type: Boolean"
                self.source.resultType(registry) != PropertyType.String: "Invalid factor type: String"
            }
            let originType = self.source.resultType(registry)
            return originType == PropertyType.NumericInt64 || originType == PropertyType.NumericFix64
                ? PropertyType.NumericFix64
                : PropertyType.NumericUFix64
        }

        pub fun execute(_ registry: &{PropertyRegistryPublic}, fromComp: &{PropertyComponentPublic}): PropertyItem {
            let originType = self.source.resultType(registry)
            let originItem = self.source.execute(registry, fromComp: fromComp)
            switch originType {
            case PropertyType.NumericInt64:
                return PropertyItem(Fix64.fromString(originItem.asInt64()!.toString().concat(".0"))!)
            case PropertyType.NumericUInt64:
                return PropertyItem(UFix64.fromString(originItem.asUInt64()!.toString().concat(".0"))!)
            case PropertyType.NumericPercentage:
                return PropertyItem(originItem.asUFix64()! * 0.01)
            case PropertyType.NumericFix64:
                return originItem
            case PropertyType.NumericUFix64:
                return originItem
            }
            panic("Unsupported type")
        }
    }

    /// Dynamic Property Factor: Addition definition
    ///
    pub struct AdditionFactorUnit: DynamicFactorUnit, DynamicFactorUnitWithChildren {
        access(self)
        let type: PropertyType
        access(contract)
        var children: [{DynamicFactorUnit}]

        init(_ type: PropertyType) {
            pre {
                type != PropertyType.Boolean && type != PropertyType.String: "Invalid factor type"
            }
            self.type = type
            self.children = []
        }

        /** ---- Implement DynamicFactorUnit ---- **/

        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType {
            return self.type
        }

        pub fun execute(
            _ registry: &{PropertyRegistryPublic},
            fromComp: &{PropertyComponentPublic}
        ): PropertyItem {
            var resultItem: PropertyItem? = nil
            for one in self.children {
                let oneResult = one.execute(registry, fromComp: fromComp)
                if resultItem != nil {
                    resultItem = resultItem!.plus(oneResult)
                } else {
                    resultItem = oneResult
                }
            }
            return resultItem ?? panic("Failed to execute factor unit")
        }
    }

    /// Dynamic Property Factor: Multiplication definition
    ///
    pub struct MultiplicationFactorUnit: DynamicFactorUnit, DynamicFactorUnitWithChildren {
        access(self)
        let type: PropertyType
        access(contract)
        var children: [{DynamicFactorUnit}]

        init(_ type: PropertyType) {
            pre {
                type != PropertyType.Boolean && type != PropertyType.String: "Invalid factor type"
            }
            self.type = type
            self.children = []
        }

        /** ---- Implement DynamicFactorUnit ---- **/

        pub view fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType {
            return self.type
        }

        pub fun execute(
            _ registry: &{PropertyRegistryPublic},
            fromComp: &{PropertyComponentPublic}
        ): PropertyItem {
            var resultItem: PropertyItem? = nil
            for one in self.children {
                let oneResult = one.execute(registry, fromComp: fromComp)
                if resultItem != nil {
                    resultItem = resultItem!.multiply(oneResult)
                } else {
                    resultItem = oneResult
                }
            }
            return resultItem ?? panic("Failed to execute factor unit")
        }
    }

    /// Dynamic Property Factor: Percentage definition
    ///
    pub struct PercentageFactorUnit: DynamicFactorUnit, DynamicFactorUnitWithChildren {
        access(contract)
        var children: [{DynamicFactorUnit}]

        init(_ type: PropertyType) {
            self.children = []
        }

        /** ---- Implement DynamicFactorUnit ---- **/

        pub fun resultType(_ registry: &{PropertyRegistryPublic}): PropertyType {
            return PropertyType.NumericPercentage
        }

        pub fun execute(
            _ registry: &{PropertyRegistryPublic},
            fromComp: &{PropertyComponentPublic}
        ): PropertyItem {
            var resultValue: UFix64 = 1.0
            for one in self.children {
                let oneResult = one.execute(registry, fromComp: fromComp)
                let oneValue = oneResult.asUFix64() ?? panic("Invalid value.")
                resultValue = resultValue * (1.0 + oneValue * 0.01)
            }
            return PropertyItem((resultValue - 1.0) * 100.0)
        }
    }

    /* --- Methods --- */

    /// To check if a property item is valid
    ///
    pub fun isPropertyItemValid(_ expectedType: PropertyType, _ item: PropertyItem): Bool {
        switch expectedType {
        case PropertyShared.PropertyType.Boolean:
            return item.asBool() != nil
        case PropertyShared.PropertyType.String:
            return item.asString() != nil
        case PropertyShared.PropertyType.NumericInt64:
            return item.asInt64() != nil
        case PropertyShared.PropertyType.NumericUInt64:
            return item.asUInt64() != nil
        case PropertyShared.PropertyType.NumericFix64:
            return item.asFix64() != nil
        case PropertyShared.PropertyType.NumericUFix64:
            return item.asUFix64() != nil
        case PropertyShared.PropertyType.NumericPercentage:
            return item.asUFix64() != nil
        }
        return false
    }

    /// To ensure a property item is valid
    ///
    pub fun ensurePropertyItemValid(_ expectedType: PropertyType, _ item: PropertyItem) {
        switch expectedType {
        case PropertyShared.PropertyType.Boolean:
            assert(item.asBool() != nil, message: "Invalid property value: not Bool")
        case PropertyShared.PropertyType.String:
            assert(item.asString() != nil, message: "Invalid property value: not String")
        case PropertyShared.PropertyType.NumericInt64:
            assert(item.asInt64() != nil, message: "Invalid property value: not Int64")
        case PropertyShared.PropertyType.NumericUInt64:
            assert(item.asUInt64() != nil, message: "Invalid property value: not UInt64")
        case PropertyShared.PropertyType.NumericFix64:
            assert(item.asFix64() != nil, message: "Invalid property value: not Fix64")
        case PropertyShared.PropertyType.NumericUFix64:
            assert(item.asUFix64() != nil, message: "Invalid property value: not UFix64")
        case PropertyShared.PropertyType.NumericPercentage:
            assert(item.asUFix64() != nil, message: "Invalid property value: not UFix64")
        }
    }
}
