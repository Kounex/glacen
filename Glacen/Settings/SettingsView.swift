// Glacen/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    let authService: RedditAuthService

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let username = authService.username {
                        Text(username)
                    }
                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.glacenBackground.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}
