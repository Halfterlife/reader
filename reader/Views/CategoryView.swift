import SwiftUI

struct CategoryView: View {
    @State private var stats: CategoryStatsResponse?
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 头部：总书数
                    if let stats = stats {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Books".localized())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("\(stats.totalBooks)")
                                    .font(.system(size: 36, weight: .bold))
                            }
                            Spacer()
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue.opacity(0.3))
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Text("All Categories".localized())
                        .font(.title2.bold())
                    
                    if isLoading {
                        ProgressView("Calculating data...".localized())
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let categories = stats?.categories, !categories.isEmpty {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(categories) { item in
                                // 点击跳转到书籍列表，传递分类名称
                                NavigationLink(destination: BookListView(selectedCategory: item.name, allCategories: categories.map { $0.name })) {
                                    CategoryCard(item: item)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No category data".localized())
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("Categories".localized())
            .hideTabBar()
            .onAppear {
                loadData()
            }
    }
    
    func loadData() {
        Task {
            do {
                let data = try await APIService.shared.fetchCategoryStats()
                await MainActor.run {
                    self.stats = data
                    self.isLoading = false
                }
            } catch {
                print("获取分类统计失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

struct CategoryCard: View {
    let item: CategoryItemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue)
                    .cornerRadius(8)
                Spacer()
                Text("\(item.count) \("Books".localized())")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Text(item.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
