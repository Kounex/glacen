import SwiftUI

@main
struct GlacenApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Glacen")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}
