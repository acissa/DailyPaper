import Foundation
import SwiftUI

/// Provides a visual sync status indicator.
struct SyncIndicator: View {
    let status: FileStorageManager.SyncStatus

    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .idle:
                Image(systemName: "cloud")
                    .foregroundStyle(.secondary.opacity(0.4))
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            case .error(let msg):
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red.opacity(0.7))
                    .help(msg)
            }
        }
        .font(.system(size: 11))
        .animation(.easeInOut(duration: 0.3), value: status)
    }
}
