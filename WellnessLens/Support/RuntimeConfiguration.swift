import Foundation

struct RuntimeConfiguration {
    let backendBaseURL: URL?
    let agentServiceBaseURL: URL?
    let isFirebaseEnabled: Bool
    let isStoreKitEnabled: Bool
    let useDemoData: Bool
    let useAppCheckDebugProvider: Bool
    let plusProductID: String?
    let proProductID: String?

    static func load(bundle: Bundle = .main) -> RuntimeConfiguration {
        let info = bundle.infoDictionary ?? [:]

        func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
            (info[key] as? Bool) ?? defaultValue
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
