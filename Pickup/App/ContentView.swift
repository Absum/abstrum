//
//  ContentView.swift
//  App shell: the practice utilities as tabs. More surfaces (Learn, Songs)
//  will join as the curriculum comes online.
//

import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PICKUP_TAB"] == "metronome" {
            _selection = State(initialValue: 1)
        }
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            TunerView()
                .tag(0)
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
            MetronomeView()
                .tag(1)
                .tabItem { Label("Metronome", systemImage: "metronome") }
        }
        .tint(Theme.teal)
    }
}

#Preview {
    ContentView()
}
