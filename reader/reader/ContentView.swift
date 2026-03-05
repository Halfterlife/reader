//
//  ContentView.swift
//  reader
//
//  Created by depin2 on 2026/1/16.
//
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var deepLinkBook: BookItem? // 用于存储通过链接打开的书籍
    @ObservedObject private var languageManager = LanguageManager.shared // 监听语言变化
    
    init() {
        // 修正 iOS 15 TabBar 透明问题
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
       TabView(selection: $selectedTab) {
            
            // 1. 书架
            BookshelfView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "books.vertical.fill" : "books.vertical")
                    Text("Shelf".localized())
                }
                .tag(0)
            
            // 2. 精选
            FeaturedView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Featured".localized())
                }
                .tag(1)
            
            // 3. 福利
            WelfareView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gift.fill" : "gift")
                    Text("Welfare".localized())
                }
                .tag(2)
            
            // 4. 我的 - 关键修改：传入 selectedTab 的绑定
            ProfileView(mainTabSelection: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("My".localized())
                }
                .tag(3)
        }
        .id(languageManager.language) // 关键：当语言变化时，强制重建整个 TabView
        .accentColor(.blue)
        // 监听外部链接唤起
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // 当获取到书籍数据时，弹出详情页
        .sheet(item: $deepLinkBook) { book in
            BookDetailView(book: book)
        }
    }
    
    // 处理链接逻辑：readerapp://book?id=xxxx
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "readerapp",
              url.host == "book",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let idItem = components.queryItems?.first(where: { $0.name == "id" }),
              let bookId = idItem.value else { return }
        
        Task {
            do {
                let book = try await APIService.shared.fetchBookDetails(bookId: bookId)
                await MainActor.run { self.deepLinkBook = book }
            } catch { print("Deep link error: \(error)") }
        }
    }
}
