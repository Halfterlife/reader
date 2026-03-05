import SwiftUI
import UIKit // 1. 需要引入 UIKit 以使用 UITabBar 扩展

struct BookDetailView: View {
    let book: BookItem
    @Environment(\.dismiss) var dismiss: DismissAction
    
    @State private var isSaved = false
    @State private var isLoadingStatus = true
    @State private var isSubmitting = false
    @State private var showShareAlert = false // 控制分享提示弹窗
    
    // 👇 新增 1：用于控制登录弹窗和获取当前登录状态
    @State private var showLoginView = false
    @AppStorage("username") private var currentUsername: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // --- 顶部导航栏 ---
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(8)
                }
                Spacer()
                Button(action: shareBook) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .foregroundColor(.primary)
            
            ScrollView {
                VStack(spacing: 25) {
                    // --- 封面与基础信息 ---
                    HStack(alignment: .top, spacing: 20) {
                        AsyncImage(url: URL(string: book.icon)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                Color.gray.opacity(0.1)
                                ProgressView()
                            }
                        }
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(book.title)
                                .font(.title2.bold())
                                .lineLimit(2)
                            
                            NavigationLink(destination: AuthorProfileView(authorName: book.author)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                    Text(book.author)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.blue)
                            }
                            
                            if let category = book.category {
                                Text(category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // --- 简介内容 ---
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Synopsis".localized())
                            .font(.headline)
                        
                        Text(book.intro)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            
            // --- 底部固定操作栏 ---
            HStack(spacing: 15) {
                // 加入书架按钮
                Button(action: toggleBookshelfServer) {
                    HStack {
                        if isLoadingStatus || isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: isSaved ? .gray : .blue))
                        } else {
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                            Text(isSaved ? "In Shelf".localized() : "Add to Shelf".localized())
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSaved ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(isSaved ? .gray : .blue)
                    .cornerRadius(12)
                }
                .disabled(isSaved || isSubmitting || isLoadingStatus)
                
                // 立即阅读按钮
                NavigationLink(destination: ReaderView(book: book)) {
                    Text("Read Now".localized())
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            .background(Color(.systemBackground).shadow(radius: 1))
        }
        .navigationBarHidden(true)
        // 👇 新增 2：挂载登录弹窗，当 showLoginView 为 true 时弹出 LoginView
        .sheet(isPresented: $showLoginView, onDismiss: {
            // 登录弹窗关闭后，重新检查一下状态
            checkStatusFromServer()
        }) {
            LoginView(isPresented: $showLoginView)
        }
        .onAppear {
            checkStatusFromServer()
        }
        .alert("Link Copied".localized(), isPresented: $showShareAlert) {
            Button("OK".localized(), role: .cancel) { }
        } message: {
            Text("Link copied to clipboard, share it with friends!".localized())
        }
        .hideTabBar()
    }
    
    // MARK: - 服务器交互逻辑
    
    func checkStatusFromServer() {
        // 👇 新增 3：如果没登录，就没必要向服务器查书架状态，直接标记未收藏
        guard !currentUsername.isEmpty else {
            self.isSaved = false
            self.isLoadingStatus = false
            return
        }
        
        Task {
            do {
                let status = try await APIService.shared.checkBookInShelf(bookId: book.id)
                await MainActor.run {
                    self.isSaved = status
                    self.isLoadingStatus = false
                }
            } catch {
                print("获取状态失败: \(error)")
                await MainActor.run { self.isLoadingStatus = false }
            }
        }
    }
    
    func toggleBookshelfServer() {
        // 👇 新增 4：最核心的拦截！没登录直接拉起登录弹窗并 return，不执行下面的网络请求
        guard !currentUsername.isEmpty else {
            showLoginView = true
            return
        }
        
        print("点击了加入书架按钮，当前 book.id: \(book.id)")
        guard !isSaved else { return }
        
        isSubmitting = true
        Task {
            do {
                let result = try await APIService.shared.addToShelf(bookId: book.id)
                print("服务器返回加入状态: \(result)")
                
                await MainActor.run {
                    if result {
                        self.isSaved = true
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBookshelf"), object: nil)
                    }
                    self.isSubmitting = false
                }
            } catch {
                print("接口请求发生错误: \(error)")
                await MainActor.run {
                    self.isSubmitting = false
                }
            }
        }
    }
    
    // 分享逻辑
    func shareBook() {
        let link = "readerapp://book?id=\(book.id)"
        UIPasteboard.general.string = link
        showShareAlert = true
    }
}
