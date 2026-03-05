// Extensions.swift (完整版)
import UIKit
import SwiftUI // 👈 必须导入 SwiftUI，否则 View 和 ViewModifier 无法使用

// MARK: - 1. UITabBar 控制逻辑
extension UITabBar {
    /// 更稳健地隐藏 / 显示 TabBar
    static func setTabBarHidden(_ hidden: Bool) {
        // 确保在主线程执行
        DispatchQueue.main.async {
            // 查找当前的 Window
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                return
            }
            
            // 递归查找 UITabBarController
            func findTabBarController(viewController: UIViewController?) -> UITabBarController? {
                guard let vc = viewController else { return nil }
                
                if let tab = vc as? UITabBarController {
                    return tab
                }
                
                // 如果是导航控制器，检查它的 tabController 属性
                if let nav = vc as? UINavigationController {
                    if let tab = nav.tabBarController { return tab }
                }
                
                // 递归查找子视图控制器
                for child in vc.children {
                    if let found = findTabBarController(viewController: child) {
                        return found
                    }
                }
                return nil
            }

            // 执行查找并隐藏
            if let tabBarController = findTabBarController(viewController: window.rootViewController) {
                // 只有状态改变时才执行，避免重复操作
                if tabBarController.tabBar.isHidden != hidden {
                    // 简单的淡入淡出动画让体验更顺滑
                    UIView.animate(withDuration: 0.2) {
                        tabBarController.tabBar.alpha = hidden ? 0 : 1
                    } completion: { _ in
                        tabBarController.tabBar.isHidden = hidden
                    }
                }
            }
        }
    }
}

// MARK: - 2. SwiftUI View 修饰符 (你之前漏掉了这部分)


struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // 页面出现时隐藏 TabBar
                UITabBar.setTabBarHidden(true)
                
            }
    }
}


extension View {
    /// 给所有 View 增加这个便捷方法，用于隐藏底部导航栏
    func hideTabBar() -> some View {
        self.modifier(HideTabBarModifier())
    }
}
