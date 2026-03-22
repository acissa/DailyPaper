import SwiftUI

struct PreferencesView: View {
    @AppStorage("customFilePath") private var customFilePath: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.system(size: 16, weight: .medium, design: .monospaced))

            VStack(alignment: .leading, spacing: 8) {
                Text("Data File Location")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))

                HStack {
                    TextField("Default (iCloud Drive)", text: $customFilePath)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.message = "Choose a folder for DailyPaper data"

                        if panel.runModal() == .OK, let url = panel.url {
                            customFilePath = url.appendingPathComponent("daily-paper.json").path
                        }
                    }
                }

                Text(customFilePath.isEmpty
                     ? "Using default: ~/Library/Mobile Documents/com~apple~CloudDocs/DailyPaper/"
                     : "Custom: \(customFilePath)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                if !customFilePath.isEmpty {
                    Button("Reset to Default") {
                        customFilePath = ""
                    }
                    .font(.system(size: 12))
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 240)
    }
}
