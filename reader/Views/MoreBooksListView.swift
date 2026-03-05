import SwiftUI

// 定义列表类型，决定页面加载什么数据
enum BookListType {
    case randomHot              // 热门随机 (对应"精选-更多")
    case newBooks               // 新书 (对应"新书-更多")
    case finished               // 完结 (对应"完结-更多")
    case categoryRandom(String) // 分类随机 (对应"热门分类-更多")
}

struct MoreBooksListView: View {
    let title: String
    let type: BookListType
    
    @State private var books: [BookItem] = []
    @State private var isLoading = true
    
    // 三列布局
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading books...".localized())
                    .padding(.top, 50)
            } else if books.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No related books".localized())
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
            } else {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(books) { book in
                        // ✅ 修复：传入 book 对象
                        NavigationLink(destination: BookDetailView(book: book)) {
                            VStack(alignment: .leading, spacing: 8) {
                                // 封面
                                AsyncImage(url: URL(string: book.icon)) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                                .frame(height: 140)
                                .cornerRadius(8)
                                .clipped()
                                
                                // 书名
                                Text(book.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                // 标签展示 (如果有)
                                if let tags = book.tags, !tags.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(tags.prefix(2), id: \.self) { tag in
                                            Text(tag)
                                                .font(.system(size: 9))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
        .hideTabBar()
    }
    
    func loadData() {
        Task {
            do {
                var fetchedBooks: [BookItem] = []
                
                switch type {
                case .randomHot:
                    // 热门随机：取20本
                    fetchedBooks = try await APIService.shared.fetchRandomBooks(limit: 20)
                    
                case .newBooks:
                    // 新书：isFinished = false, 取前20
                    let all = try await APIService.shared.fetchBooksByStatus(isFinished: false)
                    fetchedBooks = Array(all.prefix(20))
                    
                case .finished:
                    // 完结：isFinished = true, 取前20
                    let all = try await APIService.shared.fetchBooksByStatus(isFinished: true)
                    fetchedBooks = Array(all.prefix(20))
                    
                case .categoryRandom(let categoryName):
                    // 分类随机：带标签
                    fetchedBooks = try await APIService.shared.fetchRandomBooksByCategory(category: categoryName, limit: 20)
                }
                
                await MainActor.run {
                    self.books = fetchedBooks
                    self.isLoading = false
                }
            } catch {
                print("Failed to load more books".localized() + ": \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
