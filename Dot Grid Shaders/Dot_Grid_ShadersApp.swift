//
//  Dot_Grid_ShadersApp.swift
//  Dot Grid Shaders
//
//  Created by Gunnar Gray on 1/15/25.
//

import SwiftUI
import SwiftData

@main
struct Dot_Grid_ShadersApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
