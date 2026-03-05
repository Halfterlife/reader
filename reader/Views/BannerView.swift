import SwiftUI

struct BannerView: View {
    let banners: [BannerItem]
    
    var body: some View {
        TabView {
            // 如果后端没有数据，显示3个本地占位
            if banners.isEmpty {
                ForEach(0..<3) { _ in
                    PlaceholderBanner()
                }
            } else {
                ForEach(banners) { banner in
                    // 这里处理一下：如果 image 是 http 开头就加载网络图，否则显示本地占位
                    if banner.image.hasPrefix("http") {
                        AsyncImage(url: URL(string: banner.image)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                PlaceholderBanner() // 加载失败或加载中显示占位
                            }
                        }
                        .tag(banner.id)
                    } else {
                        // 如果你还没填图片，显示默认灰底
                        PlaceholderBanner()
                            .tag(banner.id)
                    }
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .frame(height: 160) // 设定一个固定高度
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// 提取出来的占位视图
struct PlaceholderBanner: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            VStack {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("广告位招租")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
