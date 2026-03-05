//
//  UserViewModel.swift
//  reader
//
//  Created by depin2 on 2026/1/22.
//
import SwiftUI

class UserViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var username: String = "点击登录账号"
    @Published var points: Int = 0
    @Published var progress: Double = 0.0

    // 签到按钮调用的函数
    func checkIn() {
        // 这里的 URL 换成你的 ngrok 地址
        let url = URL(string: "https://你的ngrok地址.ngrok-free.app/api/user/checkin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resData = json["data"] as? [String: Any] {
                    
                    // ⚠️ 关键：回到主线程更新 UI
                    DispatchQueue.main.async {
                        self.points = resData["points"] as? Int ?? self.points
                        self.progress = resData["progress"] as? Double ?? self.progress
                        print("UI已更新，书券：\(self.points)")
                    }
                }
            }
        }.resume()
    }
}
