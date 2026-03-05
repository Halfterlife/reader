import SwiftUI

// --- 已删除：SocialPost 的重复定义，统一使用 APIService 里的版本 ---

struct DiscoveryView: View {
    @State private var searchText = ""
    @State private var hotSearches: [String] = []
    @State private var communityPosts: [SocialPost] = [] // 自动关联 APIService 里的 SocialPost
    @State private var isLoading = false
    
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                TextField("Search title, author...".localized(), text: $searchText, onCommit: {
                    if !searchText.isEmpty { isSearching = true }
                })
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                // 搜索跳转隐藏链接
                NavigationLink(destination: BookListView(selectedCategory: "Search Results".localized(), allCategories: []), isActive: $isSearching) {
                    EmptyView()
                }

                List {
                    // 1. 热门搜索
                    Section(header: Text("Hot Search".localized())) {
                        if hotSearches.isEmpty {
                            Text("Loading...".localized()).foregroundColor(.gray)
                        } else {
                            ForEach(hotSearches.indices, id: \.self) { index in
                                HStack {
                                    Text("\(index + 1)").foregroundColor(index < 3 ? .orange : .gray).bold()
                                    Text(hotSearches[index])
                                }
                                .onTapGesture {
                                    searchText = hotSearches[index]
                                    isSearching = true
                                }
                            }
                        }
                    }
                    
                    // 2. 书友圈动态
                    Section(header: Text("Community".localized())) {
                        if communityPosts.isEmpty {
                            Text("No posts".localized()).foregroundColor(.gray)
                        } else {
                            ForEach(communityPosts) { post in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        // 注意：APIService 里的 SocialPost 字段是 user，不是 username
                                        Text(post.user)
                                            .font(.caption).bold()
                                            .foregroundColor(.blue)
                                        Spacer()
                                        // 假设后端在 content 里已经包含了书籍信息，或统一处理
                                        Text(post.time).font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                    Text(post.content)
                                        .font(.body)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    await fetchData()
                }
            }
            .navigationTitle("Discovery".localized())
            .onAppear {
                Task { await fetchData() }
            }
        }
    }

    // MARK: - 加载数据
    private func fetchData() async {
        isLoading = true
        do {
            // 注意：如果 APIService 还没有 getHotSearches，可以先用 mock 数据，或者补全接口
            // 暂时先只抓取动态以确保编译通过
            let posts = try await APIService.shared.getCommunityPosts()
            
            // 模拟热门搜索（如果后端还没写这个接口）
            let hot = ["剑来", "诡秘之主", "深海余烬", "灵境行者", "万相之王"]
            
            await MainActor.run {
                self.hotSearches = hot
                self.communityPosts = posts
                self.isLoading = false
            }
        } catch {
            print("发现页加载失败: \(error)")
            isLoading = false
        }
    }
}
