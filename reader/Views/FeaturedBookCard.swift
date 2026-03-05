import SwiftUI
import Kingfisher

struct FeaturedBookCard: View {
    let book: BookItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(URL(string: book.icon))
                            .placeholder { // 设置占位图
                                Rectangle().fill(Color.gray.opacity(0.1))
                            }
                            .resizable()
                            .loadDiskFileSynchronously() // 可选：稍微提升列表滚动流畅度
                            .cacheMemoryOnly() // 可选：如果不想占太多磁盘，可以只存内存，或者去掉这行默认存磁盘
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 105, height: 140)
                            .cornerRadius(8)
                            .clipped()
            
            Text(book.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(book.author)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineLimit(1)
            
            // 标签显示逻辑
            if let tags = book.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .frame(width: 105)
    }
}
