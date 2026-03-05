import StoreKit
import SwiftUI

@MainActor
class IAPManager: ObservableObject {
    static let shared = IAPManager()
    
    // 这里的 ID 需要与 App Store Connect 保持一致
    let productIds = [
        "token.5",
        "token.10",
        "token.21",
        "token.53",
        "token.105",
        "token.210"
    ]
    
    @Published var products: [Product] = []
    
    init() {
        Task {
            await updateTransactionListener()
        }
    }
    
    func fetchProducts() async {
        do {
            self.products = try await Product.products(for: productIds)
        } catch {
            print("获取产品失败: \(error)")
        }
    }
    
    // 发起购买
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // 1. 验证交易原始信息的合法性
            let transaction = try checkVerified(verification)
            
            // 2. 将 JWS 数据发送到后端进行二次验证并加币
            let serverSuccess = try await syncWithServer(verification.jwsRepresentation)
            
            if serverSuccess {
                // 3. 只有后端确认入账后，才结束苹果侧的交易
                await transaction.finish()
                return true
            } else {
                return false
            }
            
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: 1, userInfo: [NSLocalizedDescriptionKey: "苹果凭证校验不通过"])
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - 与后端通信 (原 deliverCoins 逻辑移至后端)
    
    private func syncWithServer(_ jws: String) async throws -> Bool {
        do {
            // 调用我们之前定义的 APIService 进行票据上报
            let result = try await APIService.shared.verifyPayment(receipt: jws)
            
            // 支付成功后同步一下本地的用户资产状态
            _ = try? await APIService.shared.fetchUserProfile()
            
            return result
        } catch {
            print("后端入账失败: \(error)")
            // 此时不调用 transaction.finish()，StoreKit 之后会自动重试直到后端入账成功
            return false
        }
    }
    
    // 监听漏单 (例如支付中途 App 闪退)
    private func updateTransactionListener() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                // 同样需要走后端校验
                let success = try await syncWithServer(result.jwsRepresentation)
                if success {
                    await transaction.finish()
                }
            } catch {
                print("监听器处理异常: \(error)")
            }
        }
    }
}
