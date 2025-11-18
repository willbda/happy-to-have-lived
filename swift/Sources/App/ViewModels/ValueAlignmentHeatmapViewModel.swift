//
// ValueAlignmentHeatmapViewModel.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE:
// ViewModel for Value Alignment Heatmap view.
// Manages loading goals, values, and computing semantic alignment matrix.
//
// DESIGN PATTERN:
// - @Observable + @MainActor (UI state management)
// - Lazy repository/service access with @ObservationIgnored
// - Internal properties (not public - accessed by corresponding view only)
// - ValidationError handling for user-friendly messages
//
// ARCHITECTURE:
// ValueAlignmentHeatmapViewModel → Repositories + ValueAlignmentService
//                                → EmbeddingGenerationService → NLEmbedding
//
// USAGE:
// ```swift
// @State private var viewModel = ValueAlignmentHeatmapViewModel()
//
// .task {
//     await viewModel.loadMatrix()
// }
// ```

import Foundation
import Observation
import Dependencies
import Services
import Models
import Database

/// ViewModel for Value Alignment Heatmap
///
/// **Pattern**: List ViewModel (loads data, no mutations)
/// **Concurrency**: @MainActor (UI state updates on main thread)
@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
public final class ValueAlignmentHeatmapViewModel {

    // MARK: - Observable State

    /// Alignment matrix (nil until loaded)
    var alignmentMatrix: AlignmentMatrix?

    /// Loading state
    var isLoading: Bool = false

    /// Error message (user-friendly)
    var errorMessage: String?

    /// Computed property for error display
    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies (Not Observable)

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private lazy var goalRepository: GoalRepository = {
        GoalRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var valueRepository: PersonalValueRepository = {
        PersonalValueRepository(database: database)
    }()

    @ObservationIgnored
    private lazy var alignmentService: ValueAlignmentService = {
        ValueAlignmentService(database: database)
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Load alignment matrix (fetch goals, values, compute similarities)
    ///
    /// **Flow**:
    /// 1. Set isLoading = true
    /// 2. Fetch all goals from repository
    /// 3. Fetch all values from repository
    /// 4. Compute alignment matrix via service
    /// 5. Set alignmentMatrix (triggers UI update)
    /// 6. Handle errors with user-friendly messages
    ///
    /// **Performance**:
    /// - First run: ~150ms (embedding generation + similarity computation)
    /// - Subsequent runs: ~20ms (cached embeddings)
    public func loadMatrix() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch data
            let goals = try await goalRepository.fetchAll()
            let values = try await valueRepository.fetchAll()

            // Edge case: No data
            guard !goals.isEmpty else {
                errorMessage = "No goals found. Create goals to see alignment analysis."
                isLoading = false
                return
            }

            guard !values.isEmpty else {
                errorMessage = "No values found. Add personal values to analyze goal alignment."
                isLoading = false
                return
            }

            // Compute alignment matrix
            let matrix = try await alignmentService.computeAlignmentMatrix(
                goals: goals,
                values: values
            )

            // Update UI (on main actor)
            alignmentMatrix = matrix

            print("✅ ValueAlignmentHeatmapViewModel: Loaded matrix (\(goals.count) goals × \(values.count) values)")

        } catch let error as ValidationError {
            // User-friendly validation messages
            errorMessage = error.userMessage
            print("❌ ValueAlignmentHeatmapViewModel ValidationError: \(error.userMessage)")

        } catch {
            // Generic error fallback
            errorMessage = "Failed to compute alignment matrix: \(error.localizedDescription)"
            print("❌ ValueAlignmentHeatmapViewModel: \(error)")
        }

        isLoading = false
    }

    /// Reload matrix (refresh data)
    ///
    /// **Use Case**: Pull-to-refresh or after creating new goals/values
    public func reloadMatrix() async {
        await loadMatrix()
    }

    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Helper Methods

    /// Get goal by index (safe accessor)
    ///
    /// - Parameter index: Goal index (row)
    /// - Returns: Goal if matrix loaded and index valid, nil otherwise
    func goal(at index: Int) -> GoalData? {
        guard let matrix = alignmentMatrix,
              index >= 0,
              index < matrix.goals.count else {
            return nil
        }
        return matrix.goals[index]
    }

    /// Get value by index (safe accessor)
    ///
    /// - Parameter index: Value index (column)
    /// - Returns: Value if matrix loaded and index valid, nil otherwise
    func value(at index: Int) -> PersonalValueData? {
        guard let matrix = alignmentMatrix,
              index >= 0,
              index < matrix.values.count else {
            return nil
        }
        return matrix.values[index]
    }

    /// Get cell by goal and value indices (safe accessor)
    ///
    /// - Parameters:
    ///   - goalIndex: Goal index (row)
    ///   - valueIndex: Value index (column)
    /// - Returns: Cell if matrix loaded and indices valid, nil otherwise
    func cell(goalIndex: Int, valueIndex: Int) -> AlignmentMatrix.Cell? {
        guard let matrix = alignmentMatrix,
              goalIndex >= 0,
              goalIndex < matrix.goals.count,
              valueIndex >= 0,
              valueIndex < matrix.values.count else {
            return nil
        }
        return matrix[goalIndex, valueIndex]
    }
}

// MARK: - Usage Example

/*
 // In View:
 @State private var viewModel = ValueAlignmentHeatmapViewModel()

 var body: some View {
     VStack {
         if viewModel.isLoading {
             ProgressView("Computing alignment matrix...")
         } else if let matrix = viewModel.alignmentMatrix {
             HeatmapGrid(matrix: matrix)
         } else if let error = viewModel.errorMessage {
             ErrorView(message: error)
         }
     }
     .task {
         await viewModel.loadMatrix()
     }
     .refreshable {
         await viewModel.reloadMatrix()
     }
 }
 */
