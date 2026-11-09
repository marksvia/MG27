//
//  GestaltLabApp.swift
//  GestaltLab
//

import SwiftUI

@main
struct GestaltLabApp: App {
    @StateObject private var viewModel = GestaltViewModel()

    init() {
        AutomationCommand.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
