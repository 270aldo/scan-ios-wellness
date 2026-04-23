import Foundation

extension AppModel {
    /// Permanently delete the signed-in account and wipe every local record.
    ///
    /// Implements App Store Review Guideline 5.1.1(v): apps that support
    /// account creation must also offer account deletion in-app.
    ///
    /// The method is structured as best-effort: the backend and identity
    /// calls are allowed to fail, but the local wipe and state reset always
    /// run so the usuaria never ends up in a half-deleted UI. The returned
    /// value is true if nothing errored, false otherwise. Callers may use it
    /// for telemetry or a non-blocking notice; the local reset is guaranteed
    /// regardless.
    @discardableResult
    func deleteAccount() async -> Bool {
        var allSucceeded = true

        if let backendAPI = services.backendAPI {
            do {
                try await backendAPI.deleteAccount()
            } catch {
                allSucceeded = false
            }
        }

        await services.identityProvider.deleteAccount()

        services.store.reset()
        resetToFreshState()

        return allSucceeded
    }
}
