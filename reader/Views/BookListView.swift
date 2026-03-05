import SwiftUI

struct BookListView: View {
    let selectedCategory: String
    let allCategories: [String]
    @State private var currentCategory: String
    @Environment(\.dismiss) var dismiss
    @State private var books: [BookItem] = [] // 从服务器拉回来的原始数据
    @State private var banners: [BannerItem] = []
    @State private var isLoading = false
    
    // 默认选中 "热门"
    @State private var selectedSort = "Hot".localized()
    
    // 修复后的过滤逻辑：先筛分类，再筛完结状态
    var filteredBooks: [BookItem] {
        // 1. 第一步：先找出属于当前分类（比如“玄幻”）的书
        // 如果是“精选”或“全部”，则包含所有书；否则只取 category 匹配的书
        let categoryBooks: [BookItem]
        if currentCategory == "全部" || currentCategory == "精选" || currentCategory == "Featured".localized() {
            categoryBooks = books
        } else if currentCategory == "Search Results".localized() {
            categoryBooks = books
        }
        
        else {
            categoryBooks = books.filter { $0.category == currentCategory }
        }
        
        // 2. 第二步：在当前分类的基础上，根据 Tab（热门/新书/完结）进一步筛选
        if selectedSort == "Completed".localized() {
            // 只显示已完结
            return categoryBooks.filter { $0.isCompleted == true }
        } else {
            // “热门”和“新书”显示未完结（或者你希望全部显示也可以改这里）
            return categoryBooks.filter { $0.isCompleted == false }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topCategoryHeader
            
            ScrollView {
                VStack(spacing: 0) {
                    if currentCategory == "Featured".localized() || currentCategory == "全部" {
                        bannerSection
                    }
                    
                    // 排序筛选栏
                    sortHeader
                    
                    if isLoading {
                        ProgressView("Loading...".localized())
                            .padding(.top, 50)
                    } else if filteredBooks.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No books in this category".localized())
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredBooks) { book in
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    bookRow(book: book)
                                        .padding(.horizontal)
                                }
                                Divider().padding(.leading, 110)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            fetchData()
        }
        .hideTabBar()
    }
    
    init(selectedCategory: String, allCategories: [String]) {
        self.selectedCategory = selectedCategory
        self.allCategories = allCategories
        self._currentCategory = State(initialValue: selectedCategory)
    }
    
    // MARK: - 数据请求
    private func fetchData() {
        isLoading = true
        Task {
            do {
                // 同时请求书籍和 Banner
                // 使用 currentCategory 而不是 selectedCategory，以便支持点击切换
                let fetchedBooks = try await APIService.shared.getBooksByCategory(category: currentCategory)
                // 只有在精选页才去请求 Banner
                var fetchedBanners: [BannerItem] = []
                if currentCategory == "Featured".localized() || currentCategory == "全部" {
                    fetchedBanners = try await APIService.shared.getBanners()
                }
                
                await MainActor.run {
                    self.books = fetchedBooks
                    self.banners = fetchedBanners
                    self.isLoading = false
                }
            } catch {
                print("数据请求失败: \(error)")
                isLoading = false
            }
        }
    }
    
    // MARK: - UI 子组件
    
    // 轮播图组件
    private var bannerSection: some View {
        TabView {
            ForEach(banners.isEmpty ? [BannerItem(id: "default", image: "https://picsum.photos/seed/b1/800/400", link: "")] : banners) { banner in
                AsyncImage(url: URL(string: banner.image)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            }
        }
        .frame(height: 160)
        .tabViewStyle(PageTabViewStyle())
        .cornerRadius(12)
        .padding()
    }
    
    private var topCategoryHeader: some View {
        HStack(spacing: 15) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(allCategories, id: \.self) { cat in
                        Text(cat)
                            .onTapGesture {
                                currentCategory = cat
                                fetchData()
                            }.font(.system(size: 16, weight: cat == currentCategory ? .bold : .regular))
                            .foregroundColor(cat == currentCategory ? .blue : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
    }
    
    private var sortHeader: some View {
        HStack {
            ForEach(["Hot".localized(), "New".localized(), "Completed".localized()], id: \.self) { item in
                Button(action: { selectedSort = item }) {
                    Text(item)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedSort == item ? Color.blue.opacity(0.1) : Color.clear)
                        .foregroundColor(selectedSort == item ? .blue : .gray)
                        .cornerRadius(15)
                }
            }
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func bookRow(book: BookItem) -> some View {
        HStack(alignment: .top, spacing: 15) {
            AsyncImage(url: URL(string: book.icon)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 80, height: 110).cornerRadius(4).clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title).font(.headline).foregroundColor(.primary)
                Text(book.intro).font(.subheadline).foregroundColor(.gray).lineLimit(2)
                Spacer()
                HStack {
                    Text(book.author).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(book.category ?? "Unknown".localized()).font(.system(size: 10))
                        .padding(4).overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.blue.opacity(0.5)))
                }
            }
        }
        .padding(.vertical, 12)
    }
}
