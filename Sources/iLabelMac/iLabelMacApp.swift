import SwiftUI

@main
struct iLabelMacApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1180, minHeight: 760)
                .preferredColorScheme(store.appearanceMode.colorScheme)
        }
        .windowResizability(.contentMinSize)
    }
}
