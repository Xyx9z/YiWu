//
//  ContentView.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            TabView(selection: $selectedTab) {
                MainListView()
                    .tabItem {
                        Label("记忆卡片", systemImage: "list.bullet")
                    }
                    .tag(0)
                
                IndoorNavigationView()
                    .tabItem {
                        Label("寻物助手", systemImage: "map")
                    }
                    .tag(1)
                
                CameraView(tabSelected: selectedTab == 2)
                    .tabItem {
                        Label("物品识别", systemImage: "camera")
                    }
                    .tag(2)
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
