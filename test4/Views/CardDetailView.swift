import SwiftUI

struct CardDetailView: View {
    let card: MemoryCard
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                Text(card.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // 内容
                Text(card.content)
                    .font(.body)
                    .padding(.horizontal)
                
                // 图片
                if !card.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(card.images) { imageData in
                                if let uiImage = UIImage(data: imageData.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 时间戳
                Text("创建时间：\(card.timestamp, formatter: itemFormatter)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}() 