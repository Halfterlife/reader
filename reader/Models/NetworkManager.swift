//
//  NetworkManager.swift
//  reader
//
//  Created by depin2 on 2026/1/16.
//
import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager() // 单例模式，全 App 通用
    
    // 服务器基础地址（如果你在电脑上跑 Node.js，通常是这个）
    private let baseURL = "http://localhost:3000"
    
    // 1. 获取书籍订阅状态和内容
    func fetchBookContent(title: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/book/detail?title=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                // 解析服务器返回的 JSON
                if let json = try? JSONDecoder().decode(BookResponse.self, from: data) {
                    DispatchQueue.main.async {
                        completion(json.isUnlocked, json.content)
                    }
                }
            }
        }.resume()
    }
    
    // 2. 模拟向服务器发起订阅请求
    func subscribeBook(title: String, completion: @escaping (Bool) -> Void) {
        // 实际开发这里会是一个 POST 请求，把用户 ID 和书名传给后台
        print("正在向服务器发起购买请求: \(title)...")
        
        // 模拟网络延迟 1 秒后返回成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
}

// 定义服务器返回的数据格式
struct BookResponse: Codable {
    let title: String
    let isUnlocked: Bool
    let content: String
}
