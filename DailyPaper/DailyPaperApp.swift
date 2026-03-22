import SwiftUI

@main
struct DailyPaperApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 260, idealWidth: 320,
                       minHeight: 240, idealHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .defaultSize(width: 320, height: 400)
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
