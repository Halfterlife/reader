//
//  readerApp.swift
//  reader
//
//  Created by depin2 on 2026/1/16.
//

import SwiftUI

@main
struct readerApp: App {
    // 1. 监听我们创建的语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. 将语言环境注入到所有子视图中
                .environment(\.locale, .init(identifier: languageManager.language))
        }
    }
}
