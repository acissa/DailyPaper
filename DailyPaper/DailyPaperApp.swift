import SwiftUI

@main
struct DailyPaperApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 420,
                       minHeight: 240, idealHeight: 320, maxHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 320)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Day") {
                    // Handled by the view model
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
