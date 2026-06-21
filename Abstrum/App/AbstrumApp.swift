//
//  AbstrumApp.swift
//  Abstrum — learn guitar by playing.
//

import SwiftUI
import UIKit

@main
struct AbstrumApp: App {
    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureTabBarAppearance() {
        // One source of truth for the tab bar: the system translucent blur (the
        // frosted-glass look the Chords screen has). No opaque background tint, and
        // the same appearance for standard + scroll-edge so every tab matches.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let normal = UIColor(Theme.frost.opacity(0.55))
        let selected = UIColor(Theme.teal)
        appearance.stackedLayoutAppearance.normal.iconColor = normal
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
