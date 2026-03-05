import SwiftUI

struct ProfileView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @Binding var mainTabSelection: Int

    // --- 状态变量 (使用本地化 key) ---
    @State private var username: String = "Click to log in".localized()
    @State private var userIdDisplay: String = "Sync bookshelf and assets after login".localized()
    @State private var userBookCoins: Int = 0
    @State private var userBookCoupons: Int = 0
    
    @State private var showLoginSheet = false
    @State private var cacheSize: String = "0 MB"
    @State private var showClearAlert = false
    
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false

    // 语言切换
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 顶部个人信息
                    headerUserInfoSection
                    
                    // 2. 资产卡片
                    balanceBarDisplay
                    
                    // 3. 记录快捷入口
                    HStack(spacing: 0) {
                        NavigationLink(destination: RecordListView(title: "Recharge Records".localized(), type: "recharge")) {
                            gridIconItem(icon: "gift.fill", title: "Recharge Records".localized(), color: .orange)
                        }
                        NavigationLink(destination: RecordListView(title: "Consumption Records".localized(), type: "consume")) {
                            gridIconItem(icon: "doc.text.fill", title: "Consumption Records".localized(), color: .red)
                        }
                    }
                    .padding().background(Color.white).cornerRadius(12).padding(.horizontal)

                    // 4. 功能列表
                    VStack(spacing: 0) {
                        // --- 新增：语言设置 ---
                        Section {
                            Picker("Language".localized(), selection: $languageManager.language) {
                                Text("English").tag("en")
                                Text("简体中文").tag("zh-Hans")
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        NavigationLink(destination: AccountView(mainTabSelection: $mainTabSelection)) {
                            menuRowItem(icon: "person.crop.square", title: "My Account".localized(), trailingText: "")
                        }
                        Divider().padding(.leading, 50)
                        NavigationLink(destination: FeedbackView()) {
                            menuRowItem(icon: "envelope", title: "Feedback".localized(), trailingText: "")
                        }
                        Divider().padding(.leading, 50)
                        
                        Link(destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/terms")!) {
                                                    menuRowItem(icon: "doc.text", title: "User Agreement".localized(), trailingText: "")
                                                }
                                                Divider().padding(.leading, 50)
                                                Link(destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/privacy")!) {
                                                    menuRowItem(icon: "hand.raised", title: "Privacy Policy".localized(), trailingText: "")
                                                }
                                                Divider().padding(.leading, 50)
                        
                        NavigationLink(destination: BecomeAuthorView()) {
                        menuRowItem(icon: "pencil.line", title: "Become an Author".localized(), trailingText: "")
                        }
                        Divider().padding(.leading, 50)
                        Button(action: { showClearAlert = true }) {
                            menuRowItem(icon: "trash", title: "Clear Cache".localized(), trailingText: cacheSize)
                        }
                        if isLoggedIn {
                                                    Divider().padding(.leading, 50)
                                                    Button(action: { showDeleteAccountAlert = true }) {
                                                        HStack {
                                                            Image(systemName: "person.crop.circle.badge.xmark")
                                                                .foregroundColor(.red)
                                                                .frame(width: 24)
                                                            Text("Delete Account".localized())
                                                                .font(.system(size: 16))
                                                                .foregroundColor(.red)
                                                            Spacer()
                                                            if isDeletingAccount {
                                                                ProgressView()
                                                            } else {
                                                                Image(systemName: "chevron.right")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(.gray)
                                                            }
                                                        }
                                                        .padding()
                                                        .contentShape(Rectangle())
                                                    }
                                                    .disabled(isDeletingAccount)
                                                }
                                            }
                    .background(Color.white).cornerRadius(12).padding(.horizontal)
                    
                    Text("\("Version".localized()) 1.0.0").font(.caption2).foregroundColor(.gray.opacity(0.5)).padding(.top, 10)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGray6))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshDataAsync()
            }
            .onAppear {
                UITabBar.setTabBarHidden(false)
                Task { await refreshDataAsync() }
                CacheManager.instance.getCacheSize { size in
                        self.cacheSize = size
                    }
            }
            .onChange(of: isLoggedIn) { newValue in
                Task { await refreshDataAsync() }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView(isPresented: $showLoginSheet)
            }
            .alert("Clear Cache".localized(), isPresented: $showClearAlert) {
                Button("Cancel".localized(), role: .cancel) { }
                
                Button("Confirm".localized(), role: .destructive) {
                    CacheManager.instance.clearCache {
                        // 清理完后更新界面显示为 0 KB
                        CacheManager.instance.getCacheSize { size in
                            self.cacheSize = size
                        }
                        // 可选：加个震动反馈
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            } message: {
                Text("Are you sure you want to clear all temporary files?".localized())
            }
            .alert("Delete Account".localized(), isPresented: $showDeleteAccountAlert) {
                            Button("Cancel".localized(), role: .cancel) { }
                            Button("Confirm Deletion".localized(), role: .destructive) {
                                Task {
                                    await performDeleteAccount()
                                }
                            }
                        } message: {
                            Text("Once your account is deleted, it cannot be recovered. Your coins, coupons, and reading history will be permanently erased. Are you sure you want to continue?".localized())
                        }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // --- 数据逻辑处理 ---

    private func refreshDataAsync() async {
        if isLoggedIn {
            do {
                let profile = try await APIService.shared.fetchUserProfile()
                await MainActor.run {
                    self.username = profile.username
                    self.userIdDisplay = "ID: \(profile.userId)"
                    self.userBookCoins = profile.bookCoins
                    self.userBookCoupons = profile.bookCoupons
                }
            } catch {
                print("同步个人信息失败: \(error)")
            }
        } else {
            await MainActor.run {
                self.username = "Click to log in".localized()
                self.userIdDisplay = "Sync bookshelf and assets after login".localized()
                self.userBookCoins = 0
                self.userBookCoupons = 0
            }
        }
    }

    func logoutAction() {
        // 1. 彻底清除本地存储的账号信息
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "user_token")
        
        // 如果你本地还存了书币、书券等信息，最好一并清空，防止换账号时数据串位
        UserDefaults.standard.removeObject(forKey: "userBookCoupons")
        
        // 2. 告诉 App 退出登录（这会触发 UI 刷新，变成“未登录”状态）
        isLoggedIn = false
        
        
        print("已彻底退出登录并清空了本地缓存")
    }
    
    private func performDeleteAccount() async {
            isDeletingAccount = true
            do {
                let success = try await APIService.shared.deleteAccount()
                await MainActor.run {
                    isDeletingAccount = false
                    if success {
                        // 注销成功后清除本地数据并退出登录
                        logoutAction()
                        // 可选：加个震动反馈
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    print("注销失败: \(error.localizedDescription)")
                }
            }
        }

    // --- UI 子组件 ---

    private var headerUserInfoSection: some View {
            HStack(spacing: 0) {
                if isLoggedIn {
                    // 1. 左侧点击跳转区域
                    NavigationLink(destination: EditProfileView(nickname: username, avatarUrl: "")) {
                        userInfoContent
                            .padding(.vertical)
                            .padding(.leading)
                    }
                    
                    // 2. 右侧独立的退出按钮 (放在 NavigationLink 外面)
                    Button(action: logoutAction) {
                        Text("Log Out".localized())
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(.red)
                    }
                    .padding(.trailing)
                    
                } else {
                    // 未登录状态保持原样
                    Button(action: { showLoginSheet = true }) {
                        userInfoContent
                            .padding()
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .buttonStyle(PlainButtonStyle())
        }

        private var userInfoContent: some View {
            HStack(spacing: 15) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(username).font(.headline).foregroundColor(.primary)
                    Text(userIdDisplay).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                // 提示可以点击进入的箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 5)
            }
        }


    private var balanceBarDisplay: some View {
        HStack {
            VStack {
                Text("\(userBookCoins)").font(.headline).foregroundColor(.orange)
                Text("Coins".localized()).font(.caption).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 20)
            
            VStack {
                Text("\(userBookCoupons)").font(.headline).foregroundColor(.orange)
                Text("Coupons".localized()).font(.caption).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 15)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func gridIconItem(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func menuRowItem(icon: String, title: String, trailingText: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Spacer()
            if !trailingText.isEmpty {
                Text(trailingText).font(.caption).foregroundColor(.gray)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}
