import SwiftUI

struct FeaturedView: View {
    // 搜索状态
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [BookItem] = []
    
    // 首页数据状态
    @State private var banners: [BannerItem] = []
    @State private var featuredPreview: [BookItem] = []  // 精选预览
    @State private var newBooksPreview: [BookItem] = []  // 新书预览
    @State private var finishedPreview: [BookItem] = []  // 完结预览
    @State private var categoryPreview: [BookItem] = []  // 热门分类预览
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部搜索栏
                searchBar
                    .padding(.bottom, 10)
                    .background(Color(.systemBackground))
                
                // 内容区域：搜索结果 或 首页内容
                if isSearching {
                    searchResultView
                } else {
                    homeContent
                }
            }
            .onAppear {
                UITabBar.setTabBarHidden(false)
                loadHomeData()
            }
        }
        .navigationTitle("Bookstore".localized())
        .navigationBarHidden(true)
    }
    
    // MARK: - 1. 搜索栏视图
    var searchBar: some View {
        HStack {
            // 输入框区域
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search title or author".localized(), text: $searchText)
                    .onSubmit {
                        performSearch()
                    }
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button(action: {
                        clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearching {
                // 搜索时显示“取消”
                Button("Cancel".localized()) {
                    clearSearch()
                }
                .foregroundColor(.blue)
            }
            else {
                // 未搜索时显示“分类”按钮
              NavigationLink(destination: CategoryView()) {
                  Image(systemName: "line.3.horizontal.decrease.circle")
                      .font(.system(size: 22)) // 稍微调大一点
                      .foregroundColor(.primary)
              }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // MARK: - 2. 搜索结果视图
    var searchResultView: some View {
        ScrollView {
            if searchResults.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No books found".localized())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(searchResults) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            BookCardVertical(book: book)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - 3. 首页主体内容
    var homeContent: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Banner 轮播
                if !banners.isEmpty {
                    TabView {
                        ForEach(banners) { banner in
                            AsyncImage(url: URL(string: banner.image)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                        }
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .tabViewStyle(PageTabViewStyle())
                }
                
                // 3.1 精选作品 Section
                buildSection(title: "Featured".localized(),
                             destination: MoreBooksListView(title: "Featured".localized(), type: .randomHot),
                             books: featuredPreview)
                
                // 3.2 新书速递 Section
                buildSection(title: "New Arrivals".localized(),
                             destination: MoreBooksListView(title: "New Arrivals".localized(), type: .newBooks),
                             books: newBooksPreview)
                
                // 3.3 完结精品 Section
                buildSection(title: "Completed".localized(),
                             destination: MoreBooksListView(title: "Completed".localized(), type: .finished),
                             books: finishedPreview)
                
                // 3.4 热门分类 -> 改为 随机推荐 (不再限制为 玄幻)
                buildSection(title: "Recommended".localized(), // 建议在 Localizable 添加 "Recommended" = "推荐";
                             destination: MoreBooksListView(title: "Recommended".localized(), type: .randomHot),
                             books: categoryPreview)
                
                // 底部留白
                Color.clear.frame(height: 20)
            }
            .padding(.top)
        }
    }
    
    // MARK: - 辅助方法：构建一个书籍板块
    func buildSection<Destination: View>(title: String, destination: Destination, books: [BookItem]) -> some View {
        VStack(spacing: 15) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                Spacer()
                NavigationLink(destination: destination) {
                    HStack(spacing: 4) {
                        Text("More".localized())
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // 书籍列表 (一行3个)
            if books.isEmpty {
                // 骨架屏占位
                HStack(spacing: 15) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 130)
                    }
                }
                .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(books.prefix(3)) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            BookCardVertical(book: book)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 逻辑处理
    
    func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await APIService.shared.searchBooks(keyword: searchText)
                await MainActor.run {
                    self.searchResults = results
                }
            } catch {
                print("Search failed: \(error)")
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        isSearching = false
        searchResults = []
        // 收起键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - 优化后的数据加载逻辑 (互不影响)
    func loadHomeData() {
        print("开始加载首页数据...")
        
        Task {
            // 1. 加载 Banner
            do {
                let bannersData = try await APIService.shared.getBanners()
                await MainActor.run { self.banners = bannersData }
            } catch {
                print("Banner 加载失败: \(error)")
            }
            
            // 2. 加载精选 (随机)
            do {
                let randomData = try await APIService.shared.fetchRandomBooks(limit: 3)
                await MainActor.run { self.featuredPreview = randomData }
            } catch {
                print("精选书籍加载失败: \(error)")
            }
            
            // 3. 加载新书
            do {
                let newData = try await APIService.shared.fetchBooksByStatus(isFinished: false)
                await MainActor.run { self.newBooksPreview = Array(newData.prefix(3)) }
            } catch {
                print("新书加载失败: \(error)")
            }
            
            // 4. 加载完结
            do {
                let finishedData = try await APIService.shared.fetchBooksByStatus(isFinished: true)
                await MainActor.run { self.finishedPreview = Array(finishedData.prefix(3)) }
            } catch {
                print("完结书籍加载失败: \(error)")
            }
            
            // 5. 加载分类预览
            do {
                // 改为加载随机书籍，不再传 category 参数
                let categoryData = try await APIService.shared.fetchRandomBooks(limit: 3)
                await MainActor.run { self.categoryPreview = categoryData }
            } catch {
                print("分类预览加载失败: \(error)")
            }
        }
    }
    
    // 简单的竖向书籍卡片组件 (内部使用)
    struct BookCardVertical: View {
        let book: BookItem
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: book.icon)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(height: 130)
                .cornerRadius(8)
                .clipped()
                
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
