import SwiftUI

struct AuthorProfileView: View {
    let authorName: String
    @State private var books: [BookItem] = []
    @State private var isLoading = true
    
    // 网格布局配置
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. 作者信息头
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(authorName)
                        .font(.title2)
                        .bold()
                    
                    Text("共 \(books.count) 部作品")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                Divider()
                
                // 2. 作品列表
                if isLoading {
                    ProgressView("正在加载作品...")
                        .padding(.top, 50)
                } else if books.isEmpty {
                    Text("暂无其他作品")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    // 封面
                                    AsyncImage(url: URL(string: book.icon)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            Rectangle().fill(Color.gray.opacity(0.1))
                                        }
                                    }
                                    .frame(width: 100, height: 135) // 固定封面大小
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    
                                    // 书名
                                    Text(book.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 100)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar() // 隐藏底部导航栏
        .onAppear {
            loadAuthorBooks()
        }
    }
    
    func loadAuthorBooks() {
        Task {
            do {
                let fetchedBooks = try await APIService.shared.fetchBooksByAuthor(author: authorName)
                await MainActor.run {
                    self.books = fetchedBooks
                    self.isLoading = false
                }
            } catch {
                print("加载作者书籍失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}
