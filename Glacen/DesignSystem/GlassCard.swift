import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.glacenBackground.ignoresSafeArea()
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("r/technology · 4h").font(.caption).foregroundStyle(.secondary)
                Text("New display tech could double OLED lifespan").font(.headline)
            }
        }
        .padding()
    }
}
