import SwiftUI
import StoreKit

struct StoreView: View {
    @StateObject var store = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    // 状态：当前选择的订阅周期 (0: 月度, 1: 季度, 2: 年度)
    @State private var subscriptionPeriod = 0
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // 1. VIP 订阅区
                    vipSection
                    
                    Divider()
                    
                    // 2. 书币充值区
                    coinSection
                    
                    subscriptionFooterInfo
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                    Color.clear.frame(height: 50)
                }
                .padding(.top)
            }
            
            // 3. 加载遮罩
            if store.purchasing {
                loadingOverlay
            }
        }
        .navigationTitle("Store".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Restore".localized()) {
                    Task { await store.restorePurchases() }
                }
                .font(.system(size: 14))
            }
        }
        .overlay(alignment: .bottom) {
            if !store.transactionMsg.isEmpty {
                toastMessage
            }
        }
    }
}

// MARK: - 子视图组件扩展
extension StoreView {
    
    // VIP 区域：改为计算属性，减少传参
    private var vipSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("VIP Membership".localized())
                .font(.title2).bold()
                .padding(.horizontal)
            
            Picker("Cycle".localized(), selection: $subscriptionPeriod) {
                Text("Monthly".localized()).tag(0)
                Text("Quarterly".localized()).tag(1)
                Text("Yearly".localized()).tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                vipCard(level: "gold", name: "Gold VIP".localized(), color: .orange, discount: "10% OFF".localized())
                vipCard(level: "platinum", name: "Platinum VIP".localized(), color: .blue.opacity(0.8), discount: "25% OFF".localized())
                vipCard(level: "diamond", name: "Diamond VIP".localized(), color: .purple, discount: "45% OFF".localized())
            }
            .padding(.horizontal)
        }
    }
    
    // 书币区域：修正了报错位置
    private var coinSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Coin Top Up".localized())
                    .font(.title2).bold()
                Spacer()
                Text("\("Balance: ".localized())\(store.balance)\(" Coins".localized())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(getSortedCoins()) { product in
                    coinCard(product: product)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var subscriptionFooterInfo: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Subscription & Service Terms:".localized())
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                
                Text("Subscription Terms Text".localized())
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                
                // 协议链接
                HStack(spacing: 4) {
                                Link("Auto-Renewal Agreement".localized(), destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/terms.html")!)
                                    .foregroundColor(.blue)
                                Text("|").foregroundColor(.gray)
                                Link("User Service Agreement".localized(), destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/terms.html")!)
                                    .foregroundColor(.blue)
                                Text("|").foregroundColor(.gray)
                                Link("Privacy Policy".localized(), destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/privacy.html")!)
                                    .foregroundColor(.blue)
                            }
                    .font(.caption2)
                    .tint(.blue)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

    // VIP 单个卡片组件
    @ViewBuilder
    private func vipCard(level: String, name: String, color: Color, discount: String) -> some View {
        let suffix = subscriptionPeriod == 0 ? "1m" : (subscriptionPeriod == 1 ? "3m" : "1y")
        let productId = "subscription.\(level).\(suffix)"
        let product = store.products.first(where: { $0.id == productId })
        let desc = getVipDescription(level: level)
        let reward = getTokenReward(level: level)
        
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(name).font(.headline)
                    Text(discount).font(.caption2).bold().padding(4).background(color).foregroundColor(.white).cornerRadius(4)
                }
                
                // 奖励说明
                Text("\("Token Reward: ".localized())\(reward)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange)
                
                // 详细描述
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true) // 允许换行
            }
            
            Spacer()
            
            if let p = product {
                Button(action: { Task { await store.purchase(p) } }) {
                    VStack(spacing: 0) {
                        Text(p.displayPrice).font(.system(size: 16, weight: .bold))
                        Text(subscriptionPeriod == 0 ? "/mo".localized() : (subscriptionPeriod == 1 ? "/qtr".localized() : "/yr".localized())).font(.system(size: 10))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(color)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                }
            } else {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
    
    // 获取 VIP 描述文案
    private func getVipDescription(level: String) -> String {
        let suffix = subscriptionPeriod == 0 ? "Monthly" : (subscriptionPeriod == 1 ? "Quarterly" : "Yearly")
        let key = "\(level.capitalized) Description \(suffix)"
        return key.localized()
    }
    
    // 获取 Token 奖励数量
    private func getTokenReward(level: String) -> Int {
        // Monthly
        if subscriptionPeriod == 0 {
            if level == "gold" { return 10 }
            if level == "platinum" { return 22 }
            if level == "diamond" { return 35 }
        }
        // Quarterly
        else if subscriptionPeriod == 1 {
            if level == "gold" { return 30 }
            if level == "platinum" { return 66 }
            if level == "diamond" { return 105 }
        }
        // Yearly
        else {
            if level == "gold" { return 120 }
            if level == "platinum" { return 264 }
            if level == "diamond" { return 420 }
        }
        return 0
    }

    // 书币单个卡片组件
    @ViewBuilder
    private func coinCard(product: Product) -> some View {
        Button(action: { Task { await store.purchase(product) } }) {
            VStack(spacing: 8) {
                Text(product.id.localized()).font(.headline).foregroundColor(.primary)
                
                // 赠币逻辑
                if product.id == "token.21" { Text("+Gift 1 Coin".localized()).font(.caption2).foregroundColor(.red) }
                else if product.id == "token.53" { Text("+Gift 3 Coins".localized()).font(.caption2).foregroundColor(.red) }
                else if product.id == "token.105" { Text("+Gift 5 Coins".localized()).font(.caption2).foregroundColor(.red) }
                else if product.id == "token.210" { Text("+Gift 10 Coins".localized()).font(.caption2).foregroundColor(.red) }
                else { Text(" ").font(.caption2) }
                
                Text(product.displayPrice)
                    .font(.subheadline).bold()
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1)).cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 加载中遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 15) {
                ProgressView()
                Text("Preparing payment...".localized()).font(.subheadline)
            }
            .padding(25)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
    
    // 提示信息
    private var toastMessage: some View {
        Text(store.transactionMsg)
            .font(.caption)
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.bottom, 20)
    }

    // 辅助函数：排序书币
    private func getSortedCoins() -> [Product] {
        store.products
            .filter { $0.id.contains("token") }
            .sorted { $0.price > $1.price }
    }
}
