import SwiftUI

struct IndoorNavigationView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("室内导航")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .navigationTitle("室内导航")
        }
    }
}

#Preview {
    IndoorNavigationView()
} 