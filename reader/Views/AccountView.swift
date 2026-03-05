import SwiftUI

struct AccountView: View {
    // --- 状态变量：改为由服务器驱动 ---
    @State private var userBookCoins: Int = 0
    @State private var userBookCoupons: Int = 0
    @State private var isLoading = false
    
    // 用于控制 Tab 切换
    @Binding var mainTabSelection: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            // 1. 资产展示区
            Section(header: Text("Asset Details".localized())) {
                HStack {
                    Label("My Coins".localized(), systemImage: "bitcoinsign.circle.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("\(userBookCoins)").bold()
                    }
                }
                HStack {
                    Label("My Coupons".localized(), systemImage: "ticket.fill")
                        .foregroundColor(.red)
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("\(userBookCoupons)").bold()
                    }
                }
            }
            
            // 2. 充值按钮区
            Section {
                NavigationLink(destination: StoreView().onDisappear { Task { await fetchBalance() } }) {
                    HStack {
                        Spacer()
                        Image(systemName: "creditcard.fill")
                        Text("Top Up Now".localized())
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.orange)
            }
            
            // 3. 获取书券区
            Section(footer: Text("Note: Coins are purchased, coupons are earned from events.".localized())) {
                Button(action: {
                    mainTabSelection = 2 // 跳转到福利中心 Tab
                    dismiss()
                }) {
                    Text("Get Coupons".localized())
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("My Account".localized())
        // 添加下拉刷新功能
        .refreshable {
            await fetchBalance()
        }
        .hideTabBar()
        // 页面出现时自动抓取最新余额
        .onAppear {
            Task {
                await fetchBalance()
            }
        }
    }
    
    // --- 核心逻辑：从服务器获取最新余额 ---
    private func fetchBalance() async {
        isLoading = true
        do {
            let profile = try await APIService.shared.fetchUserProfile()
            await MainActor.run {
                self.userBookCoins = profile.bookCoins
                self.userBookCoupons = profile.bookCoupons
                self.isLoading = false
            }
        } catch {
            print("刷新余额失败: \(error)")
            isLoading = false
        }
    }
}
