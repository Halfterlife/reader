import SwiftUI
import StoreKit

// 必须和你 App Store Connect 及 后端 IAP_PRODUCTS 配置一致
struct StoreConfig {
    static let productIds = [
        // 书币
        "token.5", "token.10", "token.21", "token.53", "token.105", "token.210",
        // 黄金
        "subscription.gold.1m", "subscription.gold.3m", "subscription.gold.1y",
        // 铂金
        "subscription.platinum.1m", "subscription.platinum.3m", "subscription.platinum.1y",
        // 钻石
        "subscription.diamond.1m", "subscription.diamond.3m", "subscription.diamond.1y"
    ]
}

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasing: Bool = false
    @Published var transactionMsg: String = ""
    @Published var balance: Int = 0
    
    init() {
        // 启动监听器，处理应用外购买或自动续费更新
        Task { await listenForTransactions() }
        Task { await requestProducts() }
    }
    
    // 1. 从苹果拉取商品信息
    func requestProducts() async {
        do {
            let storeProducts = try await Product.products(for: StoreConfig.productIds)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("拉取商品失败: \(error)")
        }
    }
    
    // 2. 发起购买
    func purchase(_ product: Product) async {
        purchasing = true
        transactionMsg = "正在连接 App Store..."
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                transactionMsg = "支付成功，正在验证..."
                await handleTransaction(verification)
            case .userCancelled:
                transactionMsg = "支付取消"
            case .pending:
                transactionMsg = "等待支付..."
            @unknown default:
                break
            }
        } catch {
            transactionMsg = "支付失败: \(error.localizedDescription)"
        }
        purchasing = false
    }
    
    // 3. 处理交易验证 (核心修复：B方案 - 兼容后端的老版验证)
    private func handleTransaction(_ verification: VerificationResult<StoreKit.Transaction>) async {
        switch verification {
        case .verified(let transaction):
            // 1. 获取兼容后端的 Base64 Receipt
            // 注意：这里不再使用 transaction.jsonRepresentation，而是去取系统原本的 Receipt 文件
            guard let receiptBase64 = await fetchReceiptData() else {
                transactionMsg = "无法获取支付凭证，请尝试恢复购买"
                return
            }
            
            print("拿到老版 Receipt (长度: \(receiptBase64.count))，准备发给后端...")
            
            // 2. 发送给后端 (后端 server.js 不需要改，它就认这个格式)
            let success = await APIService.shared.verifyReceipt(receipt: receiptBase64)
            
            if success {
                transactionMsg = "验证成功！权益已到账"
                await transaction.finish() // 只有后端点头，才告诉苹果交易完成
            } else {
                transactionMsg = "后端验证失败，请联系客服"
                // 失败时不要调用 transaction.finish()，这样用户重启 App 后还能补单
            }
            
        case .unverified(_, _):
            transactionMsg = "苹果验证签名失败"
        }
    }

    // ✨ 新增：获取 Receipt 的标准方法 (自动处理无凭证的情况)
    @MainActor
    private func fetchReceiptData() async -> String? {
        // 1. 尝试直接读取沙盒/正式环境的凭证文件
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path),
           let data = try? Data(contentsOf: appStoreReceiptURL) {
            return data.base64EncodedString(options: [])
        }
        
        // 2. 如果没有（常见于 Sandbox 首次安装），强制向苹果请求刷新
        print("本地无 Receipt，尝试刷新...")
        let refresher = ReceiptRefresher()
        do {
            try await refresher.refresh()
            // 刷新成功后，再次读取
            if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
               let data = try? Data(contentsOf: appStoreReceiptURL) {
                return data.base64EncodedString(options: [])
            }
        } catch {
            print("刷新 Receipt 失败: \(error)")
        }
        
        return nil
    }

    // 4. 监听交易 (处理续费) - 之前报错就是因为缺了这个
    func listenForTransactions() async {
        for await result in Transaction.updates {
            await handleTransaction(result)
        }
    }
    
    func restorePurchases() async {
            purchasing = true
            transactionMsg = "正在连接 App Store 恢复购买..."
            
            do {
                // StoreKit 2 的同步方法，会要求用户验证密码/Face ID，并刷新本地收据和交易历史
                try await AppStore.sync()
                
                // 同步完成后，获取最新的收据数据
                guard let receiptBase64 = await fetchReceiptData() else {
                    transactionMsg = "未找到任何购买记录"
                    purchasing = false
                    return
                }
                
                // 将最新收据发给后端，后端会自动解析所有的历史订阅订单并赋予 VIP 权限
                let success = await APIService.shared.verifyReceipt(receipt: receiptBase64)
                
                if success {
                    transactionMsg = "恢复成功！您的权益已更新"
                } else {
                    transactionMsg = "当前 Apple ID 下未发现有效的订阅权益"
                }
                
            } catch {
                transactionMsg = "恢复失败: \(error.localizedDescription)"
            }
            
            // 延迟一点点关闭状态，让用户能看清提示文字
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.purchasing = false
            }
        }
    
    func updateBalance(newBalance: Int) {
        self.balance = newBalance
    }
}

// MARK: - 辅助工具：将旧版代理回调转为 async/await
class ReceiptRefresher: NSObject, SKRequestDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    
    func refresh() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = SKReceiptRefreshRequest()
            request.delegate = self
            request.start()
        }
    }
    
    func requestDidFinish(_ request: SKRequest) {
        continuation?.resume()
        continuation = nil
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
