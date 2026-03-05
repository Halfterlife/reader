import SwiftUI

// 1. 管理当前语言设置
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // 使用 @AppStorage 将用户选择的语言持久化
    @AppStorage("selectedLanguage") var language: String = "en" {
        didSet {
            // 当语言变化时，通知所有观察者
            objectWillChange.send()
        }
    }
    
    // 根据当前语言获取对应的资源包 (e.g., en.lproj, zh-Hans.lproj)
    var bundle: Bundle? {
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        guard let lprojPath = path else {
            return Bundle.main // Fallback to main bundle
        }
        return Bundle(path: lprojPath)
    }
}

// 2. 扩展 String 以方便调用本地化
extension String {
    func localized() -> String {
        // 从我们自定义的 LanguageManager 获取正确的 bundle
        guard let bundle = LanguageManager.shared.bundle else {
            // 如果获取失败，使用系统默认的本地化方法
            return NSLocalizedString(self, comment: "")
        }
        // 使用指定的 bundle 进行本地化
        return NSLocalizedString(self, tableName: nil, bundle: bundle, comment: "")
    }
}
