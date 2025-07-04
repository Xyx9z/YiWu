import SwiftUI
import CoreData

struct DestinationListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var destinationStore: DestinationStore
    @State private var showingAddDestination = false
    @State private var newDestinationName = ""
    @State private var newDestinationLatitude = ""
    @State private var newDestinationLongitude = ""
    @State private var newDestinationNotes = ""
    
    init(context: NSManagedObjectContext) {
        _destinationStore = StateObject(wrappedValue: DestinationStore(context: context))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(destinationStore.destinations) { destination in
                    VStack(alignment: .leading) {
                        Text(destination.name ?? "未命名位置")
                            .font(.headline)
                        Text("经度: \(destination.longitude), 纬度: \(destination.latitude)")
                            .font(.subheadline)
                        if let notes = destination.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteDestinations)
            }
            .navigationTitle("目的地列表")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddDestination = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDestination) {
                NavigationView {
                    Form {
                        TextField("名称", text: $newDestinationName)
                        TextField("纬度", text: $newDestinationLatitude)
                            .keyboardType(.decimalPad)
                        TextField("经度", text: $newDestinationLongitude)
                            .keyboardType(.decimalPad)
                        TextField("备注", text: $newDestinationNotes)
                    }
                    .navigationTitle("添加目的地")
                    .navigationBarItems(
                        leading: Button("取消") {
                            showingAddDestination = false
                        },
                        trailing: Button("保存") {
                            saveNewDestination()
                        }
                    )
                }
            }
        }
    }
    
    private func saveNewDestination() {
        guard let latitude = Double(newDestinationLatitude),
              let longitude = Double(newDestinationLongitude) else {
            return
        }
        
        destinationStore.addDestination(
            name: newDestinationName,
            latitude: latitude,
            longitude: longitude,
            notes: newDestinationNotes
        )
        
        // 重置表单
        newDestinationName = ""
        newDestinationLatitude = ""
        newDestinationLongitude = ""
        newDestinationNotes = ""
        showingAddDestination = false
    }
    
    private func deleteDestinations(at offsets: IndexSet) {
        for index in offsets {
            let destination = destinationStore.destinations[index]
            destinationStore.deleteDestination(destination)
        }
    }
}

#Preview {
    DestinationListView(context: PersistenceController.preview.container.viewContext)
} 