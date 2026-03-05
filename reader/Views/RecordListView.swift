import SwiftUI

// --- 已删除：RecordItem 的重复定义，统一使用 APIService 里的版本 ---

struct RecordListView: View {
    let title: String
    let type: String // "recharge" or "consume"
    
    @State private var records: [RecordItem] = [] // 自动关联 APIService 里的 RecordItem
    @State private var isLoading = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView().padding()
                Spacer()
            } else if records.isEmpty {
                emptyPlaceholder
            } else {
                List(records) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            // 使用统一模型中的 title 和 time
                            Text(record.title)
                                .font(.system(size: 16))
                            Text(record.time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // 使用统一模型中的 amount
                        Text(record.amount)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(record.amount.contains("+") ? .orange : .primary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRecords()
        }
        .hideTabBar()
    }
    
    // MARK: - UI 组件
    private var emptyPlaceholder: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "doc.plaintext")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            Text("\("No".localized()) \(title)")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 数据请求
    private func loadRecords() {
        isLoading = true
        Task {
            do {
                let fetchedRecords = try await APIService.shared.fetchUserRecords(type: type)
                
                await MainActor.run {
                    self.records = fetchedRecords
                    self.isLoading = false
                }
            } catch {
                print("加载记录失败: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
