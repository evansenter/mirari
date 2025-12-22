import SwiftUI
import SwiftData

@main
struct MirariApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Card.self)
    }
}
