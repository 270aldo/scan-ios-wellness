import Foundation

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    static func configureIfNeeded(using configuration: RuntimeConfiguration) {
        guard configuration.isFirebaseEnabled else { return }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil { return }

        #if canImport(FirebaseAppCheck)
        #if DEBUG
        if configuration.useAppCheckDebugProvider {
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        }
        #endif
        #endif

        FirebaseApp.configure()
        #endif
    }
}
