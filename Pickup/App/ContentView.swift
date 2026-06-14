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
        default: break
        }
        #endif
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
        }
        .tint(Theme.teal)
    }
}

#Preview {
    ContentView()
}
