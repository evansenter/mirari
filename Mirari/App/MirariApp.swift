import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MirariApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Card.self)
    }
}
