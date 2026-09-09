import SwiftUI
import CloudKit
import UIKit

/// A SwiftUI wrapper around Apple's official `UICloudSharingController`.
/// Provides the native iOS sharing experience for CloudKit records (one-way read-only sharing).
struct CloudSharingView: UIViewControllerRepresentable {

    let share: CKShare
    let container: CKContainer
    var onDismiss: (() -> Void)? = nil
    var onStoppedSharing: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        // Strictly One-Way: Recipient can ONLY view, never edit
        controller.availablePermissions = [.allowReadOnly]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let parent: CloudSharingView

        init(_ parent: CloudSharingView) {
            self.parent = parent
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            parent.share[CKShare.SystemFieldKey.title] as? String ?? "Data Kesehatan Arterious"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            parent.onDismiss?()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            parent.onStoppedSharing?()
            parent.onDismiss?()
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ UICloudSharingController failed to save share: \(error.localizedDescription)")
        }
    }
}
