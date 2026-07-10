// Glacen/Filtered/FilteredView.swift
import SwiftUI

struct FilteredView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Filtering isn't wired up yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.glacenBackground.ignoresSafeArea())
            .navigationTitle("Filtered")
        }
    }
}
