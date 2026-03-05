import SwiftUI

struct BookshelfView: View {
    // --- 状态驱动数据 ---
    @State private var readingTime: Int = 0
    @State private var allBooks: [BookItem] = []
    
    @State private var searchText = ""
    @State private var selectedSubTab = 0 // 0: 书架, 1: 记录
    @State private var selectedBook: BookItem? = nil // 用于跳转详情
    @State private var isLoading = true // 默认为 true，但如果有缓存会立刻变为 false

    // 搜索与置顶排序逻辑
    var filteredBooks: [BookItem] {
        var list = allBooks
        
        // 排序：置顶排前
        list.sort {
            let firstPinned = $0.isPinned ?? false
            let secondPinned = $1.isPinned ?? false
            if firstPinned != secondPinned {
                return firstPinned && !secondPinned
            }
            return false
        }

        if !searchText.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. 子选项卡
                HStack(spacing: 60) {
                    subTabButton(title: "Shelf".localized(), tag: 0)
                    subTabButton(title: "History".localized(), tag: 1)
                }
                .padding(.vertical, 10)

                // 2. 列表区域
                ZStack {
                    // 优化逻辑：只有当"既没缓存数据"且"正在加载"时，才显示转圈
                    if isLoading && allBooks.isEmpty {
                        ProgressView()
                    } else {
                        booksGridView(books: filteredBooks, emptyMessage: selectedSubTab == 0 ? "Bookshelf is empty".localized() : "No history".localized())
                    }
                }
                
                // ✅ 隐藏的跳转链接：用于点击书架进入详情页
                NavigationLink(
                    destination: Group {
                        if let book = selectedBook {
                            BookDetailView(book: book)
                        }
                    },
                    isActive: Binding(
                        get: { selectedBook != nil },
                        set: { if !$0 { selectedBook = nil } }
                    )
                ) { EmptyView() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(readingTime > 0 ? "\("Read today".localized()) \(readingTime) \("min".localized())" : "No reading today".localized())
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    searchField
                }
            }
            .onAppear {
                UITabBar.setTabBarHidden(false)
                // 1. 进页面先读缓存 (秒开)
                loadFromCache()
                // 2. 后台刷新最新数据
                fetchShelfData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBookshelf"))) { _ in
                fetchShelfData()
            }
            // 切换 Tab 时也要先读该 Tab 的缓存，再刷新
            .onChange(of: selectedSubTab) { _ in
                loadFromCache()
                fetchShelfData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 服务器交互与缓存逻辑

    // 获取缓存 Key (区分书架和历史记录)
    private var currentCacheKey: String {
        return selectedSubTab == 0 ? "cache_bookshelf_list" : "cache_history_list"
    }

    func fetchShelfData() {
        // 如果当前已经有数据显示了，就不要把 isLoading 设为 true 显示转圈了，体验更好
        // 只有数据为空时才显示转圈
        if allBooks.isEmpty { isLoading = true }
        
        Task {
            do {
                let isHistory = (selectedSubTab == 1)
                let shelfBooks = try await APIService.shared.getShelfBooks(isHistory: isHistory)
                
                // 获取阅读时长
                let currentUsername = UserDefaults.standard.string(forKey: "username") ?? ""
                // 如果获取时长失败不应该中断书架流程，所以用 try?
                let status = try? await APIService.shared.getWelfareStatus(username: currentUsername)
                
                await MainActor.run {
                    self.allBooks = shelfBooks
                    if let s = status {
                        self.readingTime = s.readMins
                    }
                    self.isLoading = false
                    
                    // ✅ 请求成功后，写入缓存
                    saveToCache(shelfBooks)
                }
            } catch {
                print("同步书架失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    // ✅ 写入缓存
    func saveToCache(_ books: [BookItem]) {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: currentCacheKey)
        }
    }
    
    // ✅ 读取缓存
    func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: currentCacheKey),
           let cachedBooks = try? JSONDecoder().decode([BookItem].self, from: data) {
            self.allBooks = cachedBooks
            // 如果缓存有数据，就不显示加载动画了
            if !cachedBooks.isEmpty {
                self.isLoading = false
            }
        } else {
            // 如果没缓存，清空列表等待网络请求
            self.allBooks = []
        }
    }

    func deleteBook(_ book: BookItem) {
        Task {
            do {
                let success = try await APIService.shared.removeFromShelf(bookId: book.id)
                if success {
                    await MainActor.run {
                        allBooks.removeAll { $0.id == book.id }
                        // 删除后也要更新缓存
                        saveToCache(allBooks)
                    }
                }
            } catch { print(error) }
        }
    }

    func pinBook(_ book: BookItem) {
        Task {
            do {
                let newStatus = !(book.isPinned ?? false)
                let success = try await APIService.shared.togglePin(bookId: book.id, isPinned: newStatus)
                if success {
                    await MainActor.run {
                        if let index = allBooks.firstIndex(where: { $0.id == book.id }) {
                            allBooks[index].isPinned = newStatus
                            // 更新后更新缓存
                            saveToCache(allBooks)
                        }
                    }
                }
            } catch { print("置顶操作失败: \(error)") }
        }
    }

    // MARK: - UI 组件

    @ViewBuilder
    func booksGridView(books: [BookItem], emptyMessage: String) -> some View {
        if books.isEmpty {
            VStack { Spacer(); Text(emptyMessage).foregroundColor(.gray); Spacer() }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(books) { book in
                        // ✅ 点击改为赋值 selectedBook，触发 NavigationLink 跳转详情页
                        Button(action: { selectedBook = book }) {
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    bookCover(url: book.icon)
                                    
                                    // ✅ 置顶角标
                                    if book.isPinned ?? false {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                            .offset(x: 5, y: -5)
                                    }
                                }
                                .contextMenu {
                                    Button(action: { pinBook(book) }) {
                                        Label((book.isPinned ?? false) ? "Unpin".localized() : "Pin".localized(), systemImage: "arrow.up")
                                    }
                                    Button(role: .destructive, action: { deleteBook(book) }) {
                                        Label("Delete".localized(), systemImage: "trash")
                                    }
                                }
                                
                                Text(book.title)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
            }
            // 下拉刷新时强制请求网络
            .refreshable { fetchShelfData() }
        }
    }

    private func subTabButton(title: String, tag: Int) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedSubTab = tag
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: selectedSubTab == tag ? .bold : .medium))
                    .foregroundColor(selectedSubTab == tag ? .blue : .gray)
                Rectangle()
                    .fill(selectedSubTab == tag ? Color.blue : Color.clear)
                    .frame(width: 20, height: 3)
                    .cornerRadius(2)
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search...".localized(), text: $searchText)
                .font(.system(size: 14))
        }
        .padding(6)
        .frame(width: 120) // 稍微加宽一点，更好操作
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func bookCover(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.gray.opacity(0.1)
                Image(systemName: "book.closed").foregroundColor(.gray)
            }
        }
        .frame(width: 100, height: 140)
        .cornerRadius(6)
        .clipped()
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}
