import SwiftUI

// MARK: - 数据模型
struct ChapterResponse: Codable {
    let title: String?
    let content: String?
    let order: Int?
}

struct ChapterBrief: Codable, Identifiable {
    var id: Int { order }
    let title: String
    let order: Int
}

// MARK: - 主视图
struct ReaderView: View {
    let book: BookItem
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    
    // UI 状态
    @State private var showControls = false
    @State private var fontSize: CGFloat = 18
    @State private var selectedTheme: Color = .white
    @State private var showDirectory = false
    
    // 订阅相关 UI 状态
    @State private var showUnlockModal = false
    @State private var userCoins = 0
    @State private var userCoupons = 0
    @State private var showStore = false
    
    // 👇 新增：登录拦截相关状态
    @State private var showLoginView = false
    @AppStorage("username") private var currentUsername: String = ""
    
    // 批量订阅状态
    @State private var selectedBatchOption = 1
    @State private var customAmount = 1
    @State private var batchPrice = 0
    @State private var batchCount = 0
    @State private var isCalculatingPrice = false
    
    // 核心数据状态
    @State private var chapterTitle: String = ""
    @State private var realContent: String = ""
    @State private var currentOrder: Int = 1
    @State private var isLoading: Bool = true
    @State private var isSwitching: Bool = false
    @State private var directory: [ChapterBrief] = []
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var textColor: Color { selectedTheme == .white ? .black : .white }
    private var maxOrder: Int { directory.last?.order ?? 0 }

    var body: some View {
        ZStack {
            selectedTheme.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView().scaleEffect(1.5)
                    Text("Loading chapter...".localized()).foregroundColor(textColor)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 25) {
                            Color.clear.frame(height: 1).id("READER_TOP")
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text(book.title).font(.caption).foregroundColor(.gray)
                                Text(chapterTitle)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(textColor)
                            }
                            
                            Text(realContent)
                                .font(.system(size: fontSize))
                                .lineSpacing(10)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            bottomAutoLoadView
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { showControls.toggle() } }
                    }
                    .onChange(of: currentOrder) { _ in
                        DispatchQueue.main.async {
                            withAnimation(.none) { proxy.scrollTo("READER_TOP", anchor: .top) }
                        }
                    }
                }
            }
            
            if showUnlockModal { unlockOverlayView }
            if showControls { controlsOverlay }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.bottom)
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showDirectory) { directoryListView }
        // 改为全屏覆盖，并包裹 NavigationView 以显示标题栏和关闭按钮
        .fullScreenCover(isPresented: $showStore) {
            NavigationView {
                StoreView()
                    .navigationBarItems(leading: Button("Close".localized()) { showStore = false })
            }
        }
        // 👇 新增：挂载登录弹窗，登录成功后重新拉取该章节
        .sheet(isPresented: $showLoginView, onDismiss: {
            fetchChapterData(order: currentOrder)
        }) {
            LoginView(isPresented: $showLoginView)
        }
        .hideTabBar()
        .onAppear {
            fetchDirectory { loadSavedProgress() }
            Task {
                await APIService.shared.addToHistory(bookId: book.id)
            }
        }
        // 接收计时器事件，每分钟上报一次
        .onReceive(timer) { _ in
            guard scenePhase == .active else { return }
            if showDirectory || showStore || showUnlockModal { return }
            if isLoading { return }

            Task {
                print("上报阅读时长 +1 分钟")
                await APIService.shared.reportReadingTime(minutes: 1)
            }
        }
    }
    
    // MARK: - 自动翻页逻辑
    private var bottomAutoLoadView: some View {
        VStack(spacing: 0) {
            if !directory.isEmpty && currentOrder < maxOrder {
                if isSwitching {
                    HStack {
                        ProgressView()
                        Text(" Loading next chapter...".localized()).foregroundColor(.gray)
                    }
                    .frame(height: 80)
                } else {
                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let screenHeight = UIScreen.main.bounds.height
                        Color.clear.onChange(of: minY) { newValue in
                            if newValue < screenHeight - 40 && !isSwitching && newValue > 0 {
                                fetchChapterData(order: currentOrder + 1)
                            }
                        }
                    }
                    .frame(height: 60)
                }
            } else if !directory.isEmpty {
                VStack(spacing: 15) {
                    Divider()
                    Text("—— The End ——".localized()).font(.headline).foregroundColor(.gray)
                }
                .frame(height: 150).padding(.top, 40)
            }
        }
    }

    // MARK: - 数据请求
    private func fetchChapterData(order: Int) {
        guard !isSwitching else { return }
        if !directory.isEmpty && order > maxOrder { return }
        if order < 1 { return }
        
        isSwitching = true
        
        if let cachedChapter = CacheManager.instance.getChapter(bookId: book.id, order: order) {
            print("命中缓存: 第 \(order) 章")
            self.chapterTitle = cachedChapter.title ?? "第 \(order) 章"
            self.realContent = cachedChapter.content ?? ""
            self.currentOrder = order
            self.isLoading = false
            self.showControls = false
            self.isSwitching = false
            
            UserDefaults.standard.set(order, forKey: "progress_\(book.id)")
            
            preloadNextChapter(currentOrder: order)
            return
        }
        
        Task {
            // 先只检查单章权限
            do {
                let (unlocked, _, _, coins, coupons) = try await APIService.shared.checkChapterAccess(bookId: book.id, order: order)
                
                await MainActor.run {
                    self.userCoins = coins
                    self.userCoupons = coupons
                    if unlocked {
                        performLoad(order: order)
                    } else {
                        self.isLoading = false
                        self.isSwitching = false
                        
                        // 👇 核心拦截：如果未登录，拉起登录界面；如果已登录，弹出订阅框
                        if currentUsername.isEmpty {
                            self.showLoginView = true
                        } else {
                            self.selectedBatchOption = 1
                            self.updateBatchPrice() // 初始化价格
                            self.showUnlockModal = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isSwitching = false
                }
            }
        }
    }
    
    private func performLoad(order: Int) {
        let urlString = "http://112.124.52.158:3001/api/chapters/detail?bookId=\(book.id)&order=\(order)"
        guard let url = URL(string: urlString) else { isSwitching = false; return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                defer { self.isSwitching = false }
                
                if let data = data,
                   let res = try? JSONDecoder().decode(ChapterResponse.self, from: data),
                   let content = res.content {
                    
                    CacheManager.instance.saveChapter(bookId: book.id, order: order, title: res.title ?? "", content: content)
                    
                    self.chapterTitle = res.title ?? "第 \(order) 章"
                    self.realContent = content
                    self.currentOrder = order
                    self.isLoading = false
                    self.showControls = false
                    
                    UserDefaults.standard.set(order, forKey: "progress_\(book.id)")
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    
                    self.preloadNextChapter(currentOrder: order)
                }
            }
        }.resume()
    }
    
    private func preloadNextChapter(currentOrder: Int) {
        let nextOrder = currentOrder + 1
        if CacheManager.instance.isCached(bookId: book.id, order: nextOrder) { return }
        
        print("开始预加载第 \(nextOrder) 章...")
        Task {
            guard let (unlocked, _, _, _, _) = try? await APIService.shared.checkChapterAccess(bookId: book.id, order: nextOrder), unlocked else { return }
            
            let urlString = "http://112.124.52.158:3001/api/chapters/detail?bookId=\(book.id)&order=\(nextOrder)"
            guard let url = URL(string: urlString) else { return }
            
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let res = try? JSONDecoder().decode(ChapterResponse.self, from: data),
               let content = res.content {
                
                CacheManager.instance.saveChapter(bookId: book.id, order: nextOrder, title: res.title ?? "", content: content)
                print("预加载完成: 第 \(nextOrder) 章")
            }
        }
    }
    
    // 更新批量价格
    private func updateBatchPrice() {
        isCalculatingPrice = true
        let count: Int
        switch selectedBatchOption {
        case 0: count = customAmount // 自定义
        case 1: count = 1
        case 2: count = 20
        case 3: count = 100
        case 4: count = 99999 // 全部
        default: count = 1
        }
        
        Task {
            do {
                let res = try await APIService.shared.checkBatchAccess(
                    bookId: book.id,
                    startOrder: currentOrder + 1,
                    count: count
                )
                await MainActor.run {
                    self.batchPrice = res.totalPrice
                    self.batchCount = res.chapterCount
                    self.userCoins = res.userCoins
                    self.userCoupons = res.userCoupons ?? 0
                    self.isCalculatingPrice = false
                }
            } catch {
                await MainActor.run { self.isCalculatingPrice = false }
            }
        }
    }

    private func handleConfirmSubscribe() {
        if (userCoins + userCoupons) < batchPrice {
            showStore = true
            return
        }
        
        let count: Int
        switch selectedBatchOption {
        case 0: count = customAmount
        case 1: count = 1
        case 2: count = 20
        case 3: count = 100
        case 4: count = 99999
        default: count = 1
        }
        
        Task {
            let success = await APIService.shared.unlockBatch(
                bookId: book.id,
                startOrder: currentOrder + 1,
                count: count
            )
            await MainActor.run {
                if success {
                    self.showUnlockModal = false
                    self.isSwitching = false
                    fetchChapterData(order: currentOrder + 1)
                }
            }
        }
    }

    private func fetchDirectory(completion: (() -> Void)? = nil) {
        let urlString = "http://112.124.52.158:3001/api/books/\(book.id)/chapters"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let list = try? JSONDecoder().decode([ChapterBrief].self, from: data) {
                DispatchQueue.main.async {
                    self.directory = list.sorted(by: { $0.order < $1.order })
                    completion?()
                }
            }
        }.resume()
    }

    private func loadSavedProgress() {
        let saved = UserDefaults.standard.integer(forKey: "progress_\(book.id)")
        fetchChapterData(order: saved > 0 ? saved : 1)
    }

    // MARK: - 订阅弹窗 UI
    private var unlockOverlayView: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("Subscribe Chapter".localized())
                        .font(.title3)
                        .bold()
                    Spacer()
                    Button {
                        showUnlockModal = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                
                Text("Chapter not subscribed, please choose a plan to support the author".localized())
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // 选项网格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    subscribeOptionButton(title: "Single Chapter".localized(), sub: "This Chapter".localized(), tag: 1)
                    subscribeOptionButton(title: "Next 20".localized(), sub: "Batch".localized(), tag: 2)
                    subscribeOptionButton(title: "Next 100".localized(), sub: "Batch".localized(), tag: 3)
                    subscribeOptionButton(title: "Remaining All".localized(), sub: "Buy All".localized(), tag: 4)
                }
                
                // 自定义选项
                HStack {
                    Text("Custom:".localized())
                    Stepper("\("Next".localized()) \(customAmount) \("Chapters".localized())", value: $customAmount, in: 1...1000)
                        .onChange(of: customAmount) { _ in
                            selectedBatchOption = 0
                            updateBatchPrice()
                        }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedBatchOption == 0 ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    selectedBatchOption = 0
                    updateBatchPrice()
                }
                
                Divider()
                
                // 底部信息和按钮
                VStack(spacing: 12) {
                    HStack {
                        Text("\("Total".localized()) \(batchCount) \("Chapters".localized())")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        if isCalculatingPrice {
                            ProgressView()
                        } else {
                            paymentDetailView
                        }
                    }
                    
                    Button(action: handleConfirmSubscribe) {
                        Text((userCoins + userCoupons) >= batchPrice ? "Confirm".localized() : "Insufficient balance, Top up".localized())
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((userCoins + userCoupons) >= batchPrice ? Color.blue : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    
                    Text("\("Balance:".localized()) \(userCoins) \("Coins".localized()) + \(userCoupons) \("Coupons".localized())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(25)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
    
    // ✅ 混合支付价格展示
    private var paymentDetailView: some View {
        HStack(spacing: 4) {
            let couponDeduct = min(batchPrice, userCoupons)
            let coinDeduct = batchPrice - couponDeduct
            
            if coinDeduct > 0 && couponDeduct > 0 {
                // 混合支付
                Text("\(coinDeduct)\("Coins".localized()) + \(couponDeduct)\("Coupons".localized())")
                    .font(.headline)
                    .foregroundColor(.orange)
            } else if coinDeduct > 0 {
                // 纯书币
                Text("\(coinDeduct) \("Coins".localized())")
                    .font(.headline)
                    .foregroundColor(.orange)
            } else {
                // 纯书券
                Text("\(couponDeduct) \("Coupons".localized())")
                    .font(.headline)
                    .foregroundColor(.red)
            }
        }
    }
    
    // 选项按钮组件
    private func subscribeOptionButton(title: String, sub: String, tag: Int) -> some View {
        Button {
            selectedBatchOption = tag
            updateBatchPrice()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(selectedBatchOption == tag ? .blue : .primary)
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedBatchOption == tag ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedBatchOption == tag ? 2 : 1)
                    .background(selectedBatchOption == tag ? Color.blue.opacity(0.05) : Color.clear)
            )
        }
    }

    // MARK: - 阅读器控制层
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left").font(.title2).foregroundColor(.primary)
                }
                Spacer()
                Text(book.title).font(.headline).lineLimit(1)
                Spacer()
                Button(action: { showDirectory = true }) {
                    Image(systemName: "list.bullet").font(.title2).foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground).opacity(0.95))
            
            Spacer()
            
            VStack(spacing: 25) {
                HStack {
                    Button("Prev".localized()) { fetchChapterData(order: currentOrder - 1) }
                        .disabled(currentOrder <= 1)
                    Spacer()
                    Text("\("Chapters".localized()) \(currentOrder) / \(maxOrder)").font(.caption)
                    Spacer()
                    Button("Next".localized()) { fetchChapterData(order: currentOrder + 1) }
                        .disabled(currentOrder >= maxOrder)
                }
                
                HStack(spacing: 40) {
                    Button(action: { fontSize -= 1 }) { Image(systemName: "textformat.size.smaller") }
                    Button(action: { fontSize += 1 }) { Image(systemName: "textformat.size.larger") }
                    Spacer()
                    Button(action: { selectedTheme = (selectedTheme == .white ? Color(white: 0.15) : .white) }) {
                        Image(systemName: selectedTheme == .white ? "moon.fill" : "sun.max.fill")
                    }
                }
                .font(.title3).foregroundColor(.primary)
            }
            .padding()
            .background(Color(uiColor: .systemBackground).opacity(0.95))
            .padding(.bottom, 30)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // 目录视图
    private var directoryListView: some View {
        NavigationView {
            List(directory) { item in
                Button {
                    showDirectory = false
                    fetchChapterData(order: item.order)
                } label: {
                    HStack {
                        Text("\("Chapters".localized()) \(item.order)")
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        Text(item.title)
                            .font(.system(size: 17, weight: currentOrder == item.order ? .bold : .regular))
                            .foregroundColor(currentOrder == item.order ? .blue : .primary)
                        Spacer()
                        // 动态判断：如果不是全本免费，且当前章节号大于设定的免费章节数，才显示锁
                        if !(book.isAllFree ?? false) && item.order > (book.freeChapterCount ?? 5) {
                            Image(systemName: "lock.fill").font(.caption).foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Table of Contents".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close".localized()) { showDirectory = false } }
        }
    }
}
