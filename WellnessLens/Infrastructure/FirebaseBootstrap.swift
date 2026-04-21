import Foundation

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    enum State: String, Sendable {
        case disabled
        case configured
        case missingOptionsPlist
        case invalidOptionsPlist
        case unavailable

        var title: String {
            switch self {
            case .disabled:
                "Disabled"
            case .configured:
                "Configured"
            case .missingOptionsPlist:
                "Missing plist"
            case .invalidOptionsPlist:
                "Invalid plist"
            case .unavailable:
                "Unavailable"
            }
        }
    }

    static func configureIfNeeded(using configuration: RuntimeConfiguration, bundle: Bundle = .main) -> State {
        guard configuration.isFirebaseEnabled else { return .disabled }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil { return .configured }

        #if canImport(FirebaseAppCheck)
        #if DEBUG
        if configuration.useAppCheckDebugProvider {
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        }
        #endif
        #endif

        if let plistName = configuration.firebaseOptionsPlistName {
            guard let filePath = bundle.path(forResource: plistName, ofType: "plist") else {
                return .missingOptionsPlist
            }
            guard let options = FirebaseOptions(contentsOfFile: filePath) else {
                return .invalidOptionsPlist
            }
            FirebaseApp.configure(options: options)
            return .configured
        }

        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return .missingOptionsPlist
        }

        FirebaseApp.configure()
        return .configured
        #else
        return .unavailable
        #endif
    }
}
