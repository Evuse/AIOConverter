import SwiftUI

@main
@MainActor
struct AIOConverterApp: App {
    @StateObject private var model = ConverterModel()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
    }
}
