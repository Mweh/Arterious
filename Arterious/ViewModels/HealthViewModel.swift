import Foundation
import SwiftUI
import CloudKit

/// ViewModel managing DailyHealth state, Parent/Child role switching, and CloudKit operations.
@Observable
@MainActor
final class HealthViewModel {

    // MARK: - State

    var isParentRole: Bool = true
    var dailyHealthRecords: [DailyHealth] = []
    var sharedHealthRecords: [DailyHealth] = []

    var activeShare: CKShare?
    var isLoading: Bool = false
    var errorMessage: String?

    private let cloudKitService: CloudKitService

    init(cloudKitService: CloudKitService = .shared) {
        self.cloudKitService = cloudKitService
    }

    // MARK: - Parent Actions

    /// Creates a mock DailyHealth record with sample parent metrics.
    func saveSampleDailyHealth(
        heartRate: Double = 72.0,
        steps: Int64 = 7342,
        sleepDuration: Double = 7.2
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let newRecord = try await cloudKitService.createDailyHealth(
                date: Date(),
                heartRate: heartRate,
                steps: steps,
                sleepDuration: sleepDuration
            )
            dailyHealthRecords.insert(newRecord, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Fetches the parent's health records from their private database.
    func fetchParentRecords() async {
        isLoading = true
        errorMessage = nil

        do {
            dailyHealthRecords = try await cloudKitService.fetchDailyHealth()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Deletes a parent's record.
    func deleteParentRecord(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await cloudKitService.deleteDailyHealth(id: id)
            dailyHealthRecords.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Creates a CloudKit share so the child can access the parent's health data.
    func createShareForChild() async {
        isLoading = true
        errorMessage = nil

        do {
            activeShare = try await cloudKitService.createShare()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Child Actions

    /// Fetches shared health records from the CloudKit Shared Database.
    func fetchChildSharedRecords() async {
        isLoading = true
        errorMessage = nil

        do {
            sharedHealthRecords = try await cloudKitService.fetchSharedDailyHealth()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - General Refresh

    func refreshCurrentRole() async {
        if isParentRole {
            await fetchParentRecords()
        } else {
            await fetchChildSharedRecords()
        }
    }
}
