//
//  test4App.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI

@main
struct test4App: App {
    let persistenceController = PersistenceController.shared
    private let queue = DispatchQueue(label: "com.speech.recognizer")

    init() {
        UITabBar.appearance().backgroundColor = UIColor.white
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
