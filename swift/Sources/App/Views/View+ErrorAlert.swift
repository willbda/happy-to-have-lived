//
// View+ErrorAlert.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Standard error alert presentation for DataStore errors
// PATTERN: Extension provides consistent error handling across all views
//
// USAGE:
// List views and forms can show DataStore errors with a single modifier:
//
// ```swift
// NavigationStack {
//     List { ... }
// }
// .errorAlert(dataStore: dataStore)
// ```
//
// Or for ViewModels with errorMessage property:
//
// ```swift
// Form { ... }
// .errorAlert(errorMessage: viewModel.errorMessage) {
//     viewModel.errorMessage = nil
// }
// ```

import SwiftUI

// MARK: - DataStore Error Alert

extension View {
    /// Display error alert from DataStore
    ///
    /// **Pattern**: Observes DataStore.errorMessage and shows alert when present
    ///
    /// **Limitation**: Can't directly clear DataStore.errorMessage (not @Bindable in environment)
    /// Error clears automatically on next DataStore operation.
    ///
    /// **Usage**:
    /// ```swift
    /// @Environment(DataStore.self) private var dataStore
    ///
    /// var body: some View {
    ///     List { ... }
    ///         .errorAlert(dataStore: dataStore)
    /// }
    /// ```
    public func errorAlert(dataStore: DataStore) -> some View {
        self.alert("Error", isPresented: .constant(dataStore.errorMessage != nil)) {
            Button("OK", role: .cancel) {
                // Can't mutate dataStore directly (not @Bindable)
                // Error will clear on next operation
            }
        } message: {
            Text(dataStore.errorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Generic Error Alert (for ViewModels)

extension View {
    /// Display error alert from any error message string
    ///
    /// **Pattern**: Generic error presentation with custom dismiss action
    ///
    /// **Usage with ViewModel**:
    /// ```swift
    /// @State private var viewModel = MyFormViewModel()
    ///
    /// var body: some View {
    ///     Form { ... }
    ///         .errorAlert(errorMessage: viewModel.errorMessage) {
    ///             viewModel.errorMessage = nil
    ///         }
    /// }
    /// ```
    ///
    /// **Usage with local state**:
    /// ```swift
    /// @State private var errorMessage: String?
    ///
    /// var body: some View {
    ///     Form { ... }
    ///         .errorAlert(errorMessage: errorMessage) {
    ///             errorMessage = nil
    ///         }
    /// }
    /// ```
    public func errorAlert(
        errorMessage: String?,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}
