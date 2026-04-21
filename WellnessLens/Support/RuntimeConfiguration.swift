import Foundation

struct RuntimeConfiguration {
    let backendBaseURL: URL?
    let agentServiceBaseURL: URL?
    let isFirebaseEnabled: Bool
    let firebaseOptionsPlistName: String?
    let isBackendDebugSurfaceEnabled: Bool
    let isStoreKitEnabled: Bool
    let useDemoData: Bool
    let useAppCheckDebugProvider: Bool
    let plusProductID: String?
    let proProductID: String?

    init(
        backendBaseURL: URL?,
        agentServiceBaseURL: URL?,
        isFirebaseEnabled: Bool,
        firebaseOptionsPlistName: String?,
        isBackendDebugSurfaceEnabled: Bool = false,
        isStoreKitEnabled: Bool,
        useDemoData: Bool,
        useAppCheckDebugProvider: Bool,
        plusProductID: String?,
        proProductID: String?
    ) {
        self.backendBaseURL = backendBaseURL
        self.agentServiceBaseURL = agentServiceBaseURL
        self.isFirebaseEnabled = isFirebaseEnabled
        self.firebaseOptionsPlistName = firebaseOptionsPlistName
        self.isBackendDebugSurfaceEnabled = isBackendDebugSurfaceEnabled
        self.isStoreKitEnabled = isStoreKitEnabled
        self.useDemoData = useDemoData
        self.useAppCheckDebugProvider = useAppCheckDebugProvider
        self.plusProductID = plusProductID
        self.proProductID = proProductID
    }

    static func load(bundle: Bundle = .main) -> RuntimeConfiguration {
        let info = bundle.infoDictionary ?? [:]

        func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
            if let bool = info[key] as? Bool {
                return bool
            }
            if let raw = info[key] as? String {
                switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "1", "true", "yes":
                    return true
                case "0", "false", "no":
                    return false
                default:
                    break
                }
            }
            return defaultValue
        }

        func stringValue(_ key: String) -> String? {
            guard let raw = info[key] as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return RuntimeConfiguration(
            backendBaseURL: stringValue("WLBackendBaseURL").flatMap(URL.init(string:)),
            agentServiceBaseURL: stringValue("WLAgentServiceBaseURL").flatMap(URL.init(string:)),
            isFirebaseEnabled: boolValue("WLFirebaseEnabled", default: false),
            firebaseOptionsPlistName: stringValue("WLFirebaseOptionsPlistName"),
            isBackendDebugSurfaceEnabled: boolValue("WLBackendDebugSurfaceEnabled", default: false),
            isStoreKitEnabled: boolValue("WLStoreKitEnabled", default: false),
            useDemoData: boolValue("WLUseDemoData", default: true),
            useAppCheckDebugProvider: boolValue("WLUseAppCheckDebugProvider", default: false),
            plusProductID: stringValue("WLPlusProductID"),
            proProductID: stringValue("WLProProductID")
        )
    }

    var hasBackend: Bool {
        backendBaseURL != nil
    }

    var hasAgentService: Bool {
        agentServiceBaseURL != nil
    }
}
