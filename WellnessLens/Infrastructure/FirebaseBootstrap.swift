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
        if configuration.useAppCheckDebugProvider {
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        }
        #endif

        FirebaseApp.configure()
        #endif
    }
}
