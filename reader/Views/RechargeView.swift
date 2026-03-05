import SwiftUI
import StoreKit

struct RechargeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var iapManager = IAPManager.shared
    @State private var isProcessing = false // 新增：支付中状态

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 1. 顶部资产预览
                    assetHeader
                    
                    if iapManager.products.isEmpty {
                        Spacer()
                        ProgressView("正在拉取商品价格...")
                        Spacer()
                    } else {
                        // 2. 充值卡片列表
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(iapManager.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                                    productCard(product)
                                }
                            }
                            .padding()
                        }
                    }
                    
                    Text("充值即代表您已阅读并同意《充值协议》")
                        .font(.caption2).foregroundColor(.secondary).padding(.bottom)
                }
                
                // 3. 全局加载遮罩
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("正在处理订单...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("充值中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                await iapManager.fetchProducts()
            }
        }
    }

    // MARK: - 子视图组件
    
    private var assetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("当前书币余额").font(.caption).foregroundColor(.secondary)
                HStack(alignment: .bottom, spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill").foregroundColor(.orange)
                    Text("\(UserDefaults.standard.integer(forKey: "userBookCoins"))")
                        .font(.title.bold())
                }
            }
            Spacer()
        }
        .padding().background(Color.white)
    }

    private func productCard(_ product: Product) -> some View {
        Button(action: { handlePurchase(product) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName).font(.headline).foregroundColor(.primary)
                    Text(product.description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.yellow).foregroundColor(.black).cornerRadius(20)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isProcessing)
    }

    // MARK: - 购买逻辑处理
    private func handlePurchase(_ product: Product) {
        isProcessing = true
        Task {
            do {
                // 1. 调用系统内购
                let result = try await iapManager.purchase(product)
                
                // 2. 只有购买成功才通知后端
                if result {
                    // 这里可以再次调用 API 刷新本地余额
                    _ = try? await APIService.shared.fetchUserProfile()
                    dismiss()
                }
            } catch {
                print("购买流程中断: \(error)")
            }
            isProcessing = false
        }
    }
}
