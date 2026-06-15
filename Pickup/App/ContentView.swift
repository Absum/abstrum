//
//  ContentView.swift
//  App shell: Learn is the home; Tuner and Metronome are the practice utilities.
//

import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    init() {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["PICKUP_TAB"] {
        case "learn": _selection = State(initialValue: 0)
        case "tuner": _selection = State(initialValue: 1)
        case "metronome": _selection = State(initialValue: 2)
        case "chords": _selection = State(initialValue: 3)
        case "settings": _selection = State(initialValue: 4)
        default: break
        }
        #endif

        // Restore the frosted-glass tab bar (system blur material) on BOTH the
        // standard and scroll-edge appearances. Newer iOS defaults the scroll-edge
        // appearance to fully transparent, which let scrolled content show through
        // raw; the blur frosts whatever passes behind it instead.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            LearnHomeView()
                .tag(0)
                .tabItem { Label("Learn", systemImage: "graduationcap.fill") }
            TunerView()
                .tag(1)
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
            MetronomeView()
                .tag(2)
                .tabItem { Label("Metronome", systemImage: "metronome") }
            ChordsView()
                .tag(3)
                .tabItem { Label("Chords", systemImage: "guitars.fill") }
            SettingsView()
                .tag(4)
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.teal)
    }
}

#Preview {
    ContentView()
}
