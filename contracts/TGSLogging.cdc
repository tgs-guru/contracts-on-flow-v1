/// The contract for TGS Logging
///
pub contract TGSLogging {

    /// The interface for all TGS log entry
    ///
    pub struct interface LogEntry {
        pub let sourceType: Type
        pub let timestamp: UFix64
        pub let action: String

        pub fun toString(): String
    }

    /// The default log entry
    ///
    pub struct DefaultLogEntry: LogEntry {
        pub let sourceType: Type
        pub let timestamp: UFix64
        pub let action: String
        pub let message: String

        init(
            sourceType: Type,
            action: String,
            message: String,
        ) {
            self.sourceType = sourceType
            self.action = action
            self.message = message
            let currentBlock = getCurrentBlock()
            self.timestamp = currentBlock.timestamp
        }

        pub fun toString(): String {
            return "<".concat(self.timestamp.toString()).concat(">")
                .concat(" [").concat(self.sourceType.identifier).concat("]")
                .concat(" [").concat(self.action).concat("]")
                .concat(" ").concat(self.message)
        }
    }

    /// The interface for all TGS loggable resource
    ///
    pub resource interface LoggableResource {
        /// get the logs records reference
        ///
        pub fun getLogsRef(): &[AnyStruct{TGSLogging.LogEntry}]?

        /// Default log method
        ///
        pub fun log(
            source: Type,
            action: String,
            message: String
        ) {
            let logs = self.getLogsRef()
            logs?.append(
                DefaultLogEntry(
                    sourceType: source,
                    action: action,
                    message: message
                )
            )
        }
    }
}
