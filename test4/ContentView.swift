//
//  ContentView.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainListView()
                .tabItem {
                    Label("记忆卡片", systemImage: "list.bullet")
                }
                .tag(0)
            
            IndoorNavigationView()
                .tabItem {
                    Label("室内导航", systemImage: "map")
                }
                .tag(1)
            
            CameraView(tabSelected: selectedTab == 2)
                .tabItem {
                    Label("摄像头", systemImage: "camera")
                }
                .tag(2)
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
    ContentView()
}
