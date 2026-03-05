import Foundation
import SwiftUI

// MARK: - 1. 全局数据模型 (Models)
// 必须与 Node.js 后端返回的 JSON 字段严格一致

struct UserProfile: Codable {
    let userId: String
    let username: String
    let bookCoins: Int
    let bookCoupons: Int
    let avatar: String?
}

struct BookItem: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let icon: String
    let intro: String
    let category: String?
    let tags: [String]?
    
    let isFinished: Bool?
    let isHidden: Bool? // 1. 新增：接收隐藏状态
    let isAllFree: Bool?
    let freeChapterCount: Int?

    var isPinned: Bool?
    let bookId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, author, icon, intro, category, tags, isPinned, bookId
        case isFinished, isHidden, isAllFree, freeChapterCount
    }
    
    var isCompleted: Bool {
        return isFinished ?? false
    }
}

// 批量查询返回结构
struct BatchCheckRes: Decodable {
    let totalPrice: Int
    let chapterCount: Int
    let userCoins: Int
    let userCoupons: Int?
}

// 批量解锁返回结构
struct BatchUnlockRes: Decodable {
    let success: Bool
    let unlockedCount: Int?
    let leftCoins: Int?
    let error: String?
}

struct SocialPost: Identifiable, Codable {
    let id: Int; let user: String; let content: String; let time: String
}

struct BannerItem: Identifiable, Codable {
    let id: String // 改为 String
    let image: String
    let link: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id" // 同样映射数据库的 _id
        case image, link
    }
}

struct HomeSection: Identifiable, Codable {
    let id: String // 这里改为 String
    let title: String
    var books: [BookItem] // 3. 修改：改为 var 以便后续过滤修改
    
    enum CodingKeys: String, CodingKey {
        // 这样 Swift 就能把数据库里的 "_id" 自动装进这里的 "id" 变量里
        case id = "_id"
        case title, books
    }
}

struct CategoryStats: Codable {
    let category: String
    let totalBooks: Int?
}

struct CategoryStatsResponse: Codable {
    let totalBooks: Int
    let categories: [CategoryItemStats]
}

struct CategoryItemStats: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
}

struct RecordItem: Identifiable, Codable {
    let id: String; let title: String; let amount: String; let time: String
}

struct WelfareStatus: Codable {
    let streak: Int; let todayChecked: Bool; let readMins: Int
}

struct CheckInResult: Codable {
    let reward: Int; let newTotal: Int
}

struct VerifyPaymentResponse: Codable {
    let success: Bool; let newBalance: Int
}

struct AccessRes: Decodable {
    let isUnlocked: Bool?
    let price: Int?
    let userCoins: Int?
    let userCoupons: Int?
    let wordCount: Int?
}

// MARK: - 2. API 服务类

class APIService {
    static let shared = APIService()
    private init() {}
    
    // ⚠️ 注意：每次 ngrok 重启后，必须更新这里！
    // 结尾必须保留 /api，因为后端路由是 /api/xxx
    let baseURL = "http://112.124.52.158:3001/api"

    // 通用请求构建器
    private func createRequest(path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest {
        // path 会拼接到 baseURL 后，例如: .../api + /auth/login
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        let token = UserDefaults.standard.string(forKey: "user_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }
    
    // ✨ 新增：自动修复图片 URL 的辅助函数
    // 将数据库里的内网 IP/localhost 替换为当前的公网 IP
    private func fixBookCover(_ book: BookItem) -> BookItem {
        // 你的公网 IP
        let publicHost = "112.124.52.158:3001"
        
        // 如果图片链接包含 localhost 或 内网 IP (192.168 / 172.16-31 / 10.)
        if book.icon.contains("localhost") || book.icon.contains("192.168.") || book.icon.contains("172.") || book.icon.contains("10.") {
            // 简单粗暴替换：提取 uploads/ 及其后面的部分，拼接到公网 IP 上
            if let range = book.icon.range(of: "uploads/") {
                let suffix = book.icon[range.lowerBound...] // 得到 "uploads/xxx.png"
                let newUrl = "http://\(publicHost)/\(suffix)"
                
                return BookItem(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    icon: newUrl, // ✅ 替换为新 URL
                    intro: book.intro,
                    category: book.category,
                    tags: book.tags,
                    isFinished: book.isFinished,
                    isHidden: book.isHidden,
                    isAllFree: book.isAllFree,
                    freeChapterCount: book.freeChapterCount,
                    isPinned: book.isPinned,
                    bookId: book.bookId
                )
            }
        }
        return book
    }

    // MARK: - 认证与反馈
    
    func login(username: String, password: String) async throws -> String {
        let body = ["username": username, "password": password]
        let request = createRequest(path: "/auth/login", method: "POST", body: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // 解析 Token
        let result = try JSONDecoder().decode([String: String].self, from: data)
        let token = result["token"] ?? ""
        

        await MainActor.run {
            UserDefaults.standard.set(token, forKey: "user_token")
            UserDefaults.standard.set(true, forKey: "isLoggedIn") // 让 App 知道已登录
            UserDefaults.standard.set(username, forKey: "username")
        }
        
        return token
    }
    
    func register(username: String, password: String) async throws -> Bool {
        let body = ["username": username, "password": password]
        let request = createRequest(path: "/auth/register", method: "POST", body: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode
        return code == 200 || code == 201
    }

    func updateProfile(newNickname: String, avatarUrl: String) async throws -> Bool {
        let oldName = UserDefaults.standard.string(forKey: "username") ?? ""
        // 注意：这里的 key 必须和 server.js 中 app.post('/api/user/update') 接收的 body 一致
        let body: [String: Any] = [
            "oldUsername": oldName,
            "newUsername": newNickname,
            "avatar": avatarUrl
        ]
        let request = createRequest(path: "/user/update", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let success = (response as? HTTPURLResponse)?.statusCode == 200
        return success
    }
    
    func postFeedback(content: String, contact: String) async throws -> Bool {
        let body = ["content": content, "contact": contact]
        let request = createRequest(path: "/user/feedback", method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    // MARK: - 账号注销
        func deleteAccount() async throws -> Bool {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            guard !username.isEmpty else { return false }
            
            let body: [String: Any] = ["username": username]
            let request = createRequest(path: "/user/delete", method: "DELETE", body: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        }

    // MARK: - 首页与分类
    
    func fetchUserProfile() async throws -> UserProfile {
        // 从本地获取当前登录的用户名
        let currentName = UserDefaults.standard.string(forKey: "username") ?? ""
        
        // 将用户名作为查询参数传递给后端
        let request = createRequest(path: "/user/profile?username=\(currentName)")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func getBanners() async throws -> [BannerItem] {
        let request = createRequest(path: "/home/banners")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([BannerItem].self, from: data)
    }

    func getHomeSections() async throws -> [HomeSection] {
        let request = createRequest(path: "/home/sections")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 关键调试：看看到底回了什么
        if let str = String(data: data, encoding: .utf8) {
            print("--- 收到数据内容 ---")
            print(str)
            print("------------------")
        }
        
        // 4. 修改：在客户端进行双重过滤，确保不显示隐藏或没有标题的书
        var sections = try JSONDecoder().decode([HomeSection].self, from: data)
        for i in 0..<sections.count {
            // 先修复图片链接，再过滤
            sections[i].books = sections[i].books.map { fixBookCover($0) }.filter { book in
                // 一本书必须是“非隐藏”且“标题不为空白”才被认为是有效的
                return book.isHidden != true
                    && !book.title.trimmingCharacters(in: .whitespaces).isEmpty

            }
        }
        return sections
    }

    func getCategoryStats() async throws -> CategoryStats {
        let request = createRequest(path: "/category/stats")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(CategoryStats.self, from: data)
    }

    func getBooksByCategory(category: String) async throws -> [BookItem] {
        let encoded = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
        let request = createRequest(path: "/books?category=\(encoded)")
        let (data, _) = try await URLSession.shared.data(for: request)
        // 5. 修改：过滤分类列表里的隐藏书
        let books = try JSONDecoder().decode([BookItem].self, from: data)
        return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
    }

    // MARK: - 书架逻辑

    func getShelfBooks(isHistory: Bool) async throws -> [BookItem] {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            
            // ✅ 关键修改：如果是历史记录，请求 /history/list，否则请求 /shelf/list
            let endpoint = isHistory ? "/history/list" : "/shelf/list"
            let path = "\(endpoint)?username=\(username)"
            
            let request = createRequest(path: path, method: "GET", body: nil)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }
        }

        // 2. 新增：添加阅读历史的方法
        func addToHistory(bookId: String) async {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            if username.isEmpty { return }
            
            let body: [String: Any] = ["username": username, "bookId": bookId]
            // 这里不需要处理返回值，发出去就行
            _ = try? await URLSession.shared.data(for: createRequest(path: "/history/add", method: "POST", body: body))
        }



    func checkBookInShelf(bookId: String) async throws -> Bool {
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        // 确保 URL 参数名与后端 getUsernameFromReq 获取的一致
        let path = "/shelf/check?bookId=\(bookId)&username=\(username)"
        
        let request = createRequest(path: path, method: "GET", body: nil)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonStr = String(data: data, encoding: .utf8) {
            print("🔍 检查状态后端返回: \(jsonStr)")
        }
        
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let isSaved = result["isSaved"] as? Bool {
            return isSaved
        }
        return false
    }

    func addToShelf(bookId: String) async throws -> Bool {
        // 1. 获取本地存储的用户名（必须确保存储时 key 是 "username"）
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        
        // 2. 将 username 加入请求体 body
        let body: [String: Any] = [
            "bookId": bookId,
            "username": username
        ]
        
        // 3. 发送请求
        let request = createRequest(path: "/shelf/add", method: "POST", body: body)
        
        print("📡 发送添加请求: 用户[\(username)], 书籍ID[\(bookId)]")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 HTTP 状态码: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 后端原始返回内容: \(responseString)")
            }
            
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 201
        }
        return false
    }
        
    func removeFromShelf(bookId: String) async throws -> Bool {
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        
        // 💡 必须确传给后端的 body 包含 username 和 bookId
        let body: [String: Any] = [
            "bookId": bookId,
            "username": username
        ]
        
        let request = createRequest(path: "/shelf/remove", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("删除响应状态码: \(httpResponse.statusCode)")
            return httpResponse.statusCode == 200
        }
        return false
    }

        func togglePin(bookId: String, isPinned: Bool) async throws -> Bool {
            let body: [String: Any] = ["bookId": bookId, "isPinned": isPinned]
            let request = createRequest(path: "/shelf/pin", method: "POST", body: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        }
    // MARK: - 阅读器与发现页
    
    func reportReadingProgress(bookId: String, chapterIndex: Int, progress: Double) async throws { // Int -> String
        let body: [String: Any] = ["bookId": bookId, "chapterIndex": chapterIndex, "progress": progress]
        _ = try await URLSession.shared.data(for: createRequest(path: "/reader/progress", method: "POST", body: body))
    }

    func unlockChapter(bookId: String, chapterIndex: Int) async throws -> Bool { // Int -> String
        let body: [String: Any] = ["bookId": bookId, "chapterIndex": chapterIndex]
        let request = createRequest(path: "/reader/unlock", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if (response as? HTTPURLResponse)?.statusCode == 200 {
            let res = try? JSONDecoder().decode([String: Bool].self, from: data)
            return res?["success"] ?? false
        }
        return false
    }

    func getCommunityPosts() async throws -> [SocialPost] {
        let request = createRequest(path: "/discovery/posts")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([SocialPost].self, from: data)
    }

    func fetchStoreBooks() async throws -> [BookItem] { // 修改返回类型
        let request = createRequest(path: "/books", method: "GET", body: nil)
        let (data, _) = try await URLSession.shared.data(for: request)
        // 6. 修改：过滤书库里的隐藏书
        let books = try JSONDecoder().decode([BookItem].self, from: data)
        return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
    }
    
    // MARK: - 福利、支付与记录 (关键部分)
    
    func getWelfareStatus(username: String) async throws -> WelfareStatus {
        // 将 username 作为查询参数拼接到 URL 后面
        let path = "/welfare/status?username=\(username)"
        
        let request = createRequest(path: path, method: "GET", body: nil)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(WelfareStatus.self, from: data)
    }
    func submitCheckIn() async throws -> CheckInResult {
        let currentName = UserDefaults.standard.string(forKey: "username") ?? ""
        // 必须把 username 传过去
        let body = ["username": currentName]
        
        let request = createRequest(path: "/welfare/checkin", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(CheckInResult.self, from: data)
        
        // 更新本地显示
        await MainActor.run {
            UserDefaults.standard.set(result.newTotal, forKey: "userBookCoupons")
        }
        
        return result
    }

    func verifyPayment(receipt: String) async throws -> Bool {
        let request = createRequest(path: "/payment/verify", method: "POST", body: ["receipt": receipt])
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if (response as? HTTPURLResponse)?.statusCode == 200 {
            let res = try? JSONDecoder().decode(VerifyPaymentResponse.self, from: data)
            return res?.success ?? false
        }
        return false
    }

    func fetchUserRecords(type: String) async throws -> [RecordItem] {
        let encoded = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type
        let request = createRequest(path: "/user/records?type=\(encoded)")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([RecordItem].self, from: data)
    }

    func getMoreBooks(title: String) async throws -> [BookItem] {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let request = createRequest(path: "/books?category=\(encoded)")
        let (data, _) = try await URLSession.shared.data(for: request)
        // 7. 修改：过滤更多推荐里的隐藏书
        let books = try JSONDecoder().decode([BookItem].self, from: data)
        return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
    }
    // 1. 检查权限
    func checkChapterAccess(bookId: String, order: Int) async throws -> (Bool, Int, Bool, Int, Int) {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            let body: [String: Any] = ["username": username, "bookId": bookId, "chapterOrder": order]
            
            let url = URL(string: "\(baseURL)/reader/check-access")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let res = try JSONDecoder().decode(AccessRes.self, from: data)
            
            let unlocked = res.isUnlocked ?? false
            let price = res.price ?? 0
            let coins = res.userCoins ?? 0
            let coupons = res.userCoupons ?? 0 // 获取书券
            
            // 判断是否买得起 (书币 + 书券 >= 价格)
            let canAfford = (coins + coupons) >= price
            
            // 返回 (是否解锁, 价格, 是否买得起, 书币余额, 书券余额)
            return (unlocked, price, canAfford, coins, coupons)
        }

    // 2. 执行解锁
    func unlockChapter(bookId: String, order: Int, price: Int) async -> Bool {
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        let url = URL(string: "http://112.124.52.158/api/reader/unlock")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["username": username, "bookId": bookId, "chapterOrder": order, "price": price])
        
        do { let (_, response) = try await URLSession.shared.data(for: request); return (response as? HTTPURLResponse)?.statusCode == 200 } catch { return false }
    }

    // 在 APIService 类中添加
    func verifyReceipt(receipt: String) async -> Bool {
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        guard let url = URL(string: "http://112.124.52.158/api/payment/verify") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["username": username, "receipt": receipt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("收据验证请求失败: \(error)")
            return false
        }
    }
    
        
        func fetchBooksByCategory(_ category: String) async throws -> [BookItem] {
            guard let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw URLError(.badURL)
            }

            // 2. 拼接 URL
            let urlString = "\(baseURL)/books?category=\(encodedCategory)"
            
            guard let url = URL(string: urlString) else {
                throw URLError(.badURL)
            }
            
            print("正在请求分类书籍: \(urlString)")
            
            // 3. 发送请求
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 8. 修改：过滤分类结果
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }
    
    // 获取分类统计数据 (匹配 CategoryView 的调用)
        func fetchCategoryStats() async throws -> CategoryStatsResponse {
            // 对应 server.js 中的 app.get('/api/categories/stats', ...)
            let request = createRequest(path: "/categories/stats")
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(CategoryStatsResponse.self, from: data)
        }
    
        // 1. 搜索书籍 (支持书名或作者)
        func searchBooks(keyword: String) async throws -> [BookItem] {
            guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
            // 调用我们刚才修改的接口，传入 keyword
            let request = createRequest(path: "/books?keyword=\(encoded)")
            let (data, _) = try await URLSession.shared.data(for: request)
            // 9. 修改：搜索结果也不显示隐藏书
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }

        // 2. 获取随机书籍 (用于"精选更多")
        func fetchRandomBooks(limit: Int = 20) async throws -> [BookItem] {
            let request = createRequest(path: "/books/random?limit=\(limit)")
            let (data, _) = try await URLSession.shared.data(for: request)
            // 10. 修改：过滤随机推荐
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }

        // 3. 根据完结状态获取书籍 (用于"新书"和"完结")
        func fetchBooksByStatus(isFinished: Bool) async throws -> [BookItem] {
            let request = createRequest(path: "/books?isFinished=\(isFinished)")
            let (data, _) = try await URLSession.shared.data(for: request)
            // 11. 修改：过滤新书/完结
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }
        
        // 4. 获取特定分类的随机书籍 (用于"热门分类更多")
        func fetchRandomBooksByCategory(category: String, limit: Int = 20) async throws -> [BookItem] {
            let encoded = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
            let request = createRequest(path: "/books/random?category=\(encoded)&limit=\(limit)")
            let (data, _) = try await URLSession.shared.data(for: request)
            // 12. 修改：过滤分类随机
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }
    
    // 批量查询价格
    func checkBatchAccess(bookId: String, startOrder: Int, count: Int) async throws -> BatchCheckRes {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            let body: [String: Any] = [
                "username": username,
                "bookId": bookId,
                "startOrder": startOrder,
                "count": count
            ]
            
            let url = URL(string: "\(baseURL)/reader/check-batch-access")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(BatchCheckRes.self, from: data)
        }
        // 批量解锁执行
        func unlockBatch(bookId: String, startOrder: Int, count: Int) async -> Bool {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            let body: [String: Any] = [
                "username": username,
                "bookId": bookId,
                "startOrder": startOrder,
                "count": count
            ]
            
            let url = URL(string: "\(baseURL)/reader/batch-unlock")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    let res = try? JSONDecoder().decode(BatchUnlockRes.self, from: data)
                    return res?.success ?? false
                }
                return false
            } catch {
                return false
            }
        }
    
    func applyAuthor(realName: String, contact: String, intro: String) async throws -> Bool {
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        let body: [String: Any] = [
            "username": username,
            "realName": realName,
            "contact": contact,
            "intro": intro
        ]
        let request = createRequest(path: "/user/apply-author", method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func uploadImage(image: UIImage) async throws -> String? {
        let url = URL(string: "\(baseURL)/upload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 压缩图片，0.6 可以在保证清晰度的情况大幅减小体积
        guard let imageData = image.jpegData(compressionQuality: 0.6) else { return nil }
        
        // 拼接 Multipart Form Data 数据体
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let fileUrl = json["url"] as? String {
            return fileUrl
        }
        return nil
    }
    
        func fetchBooksByAuthor(author: String) async throws -> [BookItem] {
            guard let encoded = author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
            let request = createRequest(path: "/books?author=\(encoded)")
            let (data, _) = try await URLSession.shared.data(for: request)
            // 13. 修改：过滤作者书籍列表
            let books = try JSONDecoder().decode([BookItem].self, from: data)
            return books.map { fixBookCover($0) }.filter { $0.isHidden != true }
        }
    
    // 14. 新增：根据 ID 获取书籍详情 (用于 Deep Link 跳转)
    func fetchBookDetails(bookId: String) async throws -> BookItem {
        let request = createRequest(path: "/books/\(bookId)")
        let (data, _) = try await URLSession.shared.data(for: request)
        let book = try JSONDecoder().decode(BookItem.self, from: data)
        return fixBookCover(book)
    }
    
    func reportReadingTime(minutes: Int) async {
            let username = UserDefaults.standard.string(forKey: "username") ?? ""
            guard !username.isEmpty else { return }
            
            let body: [String: Any] = ["username": username, "minutes": minutes]
            let url = URL(string: "\(baseURL)/user/add-read-time")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            try? await URLSession.shared.data(for: request)
        }

}
