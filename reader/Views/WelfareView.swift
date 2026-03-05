import SwiftUI

struct WelfareView: View {
    @State private var consecutiveDays: Int = 0
    @State private var todayCheckedIn: Bool = false
    @State private var readingMinutes: Int = 0
    @State private var isLoading: Bool = true
    @State private var showSuccessAlert = false
    @State private var lastRewardAmount = 0
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    @AppStorage("userBookCoupons") private var userBookCoupons: Int = 0
    
    // 👇 新增 1：用于控制登录弹窗和获取登录状态
    @State private var showLoginView = false
    @AppStorage("username") private var currentUsername: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    checkInCard
                    readingTaskCard
                    ruleSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGray6))
            .navigationTitle("Welfare Center".localized())
            .onAppear {
                UITabBar.setTabBarHidden(false)
                syncWithServer()
            }
            // 👇 新增 2：挂载登录弹窗
            .sheet(isPresented: $showLoginView, onDismiss: {
                // 登录完成后，刷新福利中心数据
                syncWithServer()
            }) {
                LoginView(isPresented: $showLoginView)
            }
            .alert("Check-in Successful".localized(), isPresented: $showSuccessAlert) {
                Button("Great".localized(), role: .cancel) { }
            } message: {
                Text("\("Congratulations! You got".localized()) \(lastRewardAmount) \("Coupons".localized())，\("Keep checking in for more rewards!".localized())")
            }
            .alert("Tip".localized(), isPresented: $showErrorAlert) { Button("Confirm".localized(), role: .cancel) { } } message: { Text(errorMessage) }
        }
    }

    // MARK: - UI 组件库

    private var checkInCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Consecutive Check-ins".localized()).font(.subheadline).foregroundColor(.secondary)
                    Text("\(consecutiveDays) \("Days".localized())")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                Spacer()
                let nextReward = calculateReward(for: consecutiveDays + 1)
                VStack(alignment: .trailing) {
                    Text("\("Tomorrow get".localized()) \(nextReward) \("Coupons".localized())")
                        .font(.caption).bold()
                        .padding(8).background(Color.orange.opacity(0.1))
                        .cornerRadius(8).foregroundColor(.orange)
                }
            }
            
            Button(action: handleCheckIn) {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        // 根据 todayCheckedIn 动态切换文字
                        Text(todayCheckedIn ? "Come back tomorrow".localized() : "\("Check in now".localized()) (+\(calculateReward(for: consecutiveDays + 1))\("Coupons".localized()))")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                // 根据状态变色：签过后变成灰色
                .background(todayCheckedIn ? Color.gray.opacity(0.5) : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(todayCheckedIn || isLoading) // 签过后禁用按钮
        }
        .padding().background(Color.white).cornerRadius(20).padding(.horizontal)
    }

    private var readingTaskCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Daily Reading Tasks".localized()).font(.headline)
                Spacer()
                Text("\("Read today".localized()) \(readingMinutes) \("min".localized())").font(.caption).foregroundColor(.secondary)
            }
            
            taskRow(title: "Read 10 mins".localized(), reward: 10, current: readingMinutes, target: 10)
            Divider()
            taskRow(title: "Read 30 mins".localized(), reward: 30, current: readingMinutes, target: 30)
            Divider()
            taskRow(title: "Read 60 mins".localized(), reward: 50, current: readingMinutes, target: 60)
        }
        .padding().background(Color.white).cornerRadius(20).padding(.horizontal)
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules:".localized()).font(.caption.bold())
            Text("Rules Text".localized()).font(.caption2)
        }
        .foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 30)
    }

    // --- 逻辑函数 ---

    private func calculateReward(for day: Int) -> Int {
        min(day * 5, 30)
    }

    private func taskRow(title: String, reward: Int, current: Int, target: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).bold()
                Text("\("Reward: ".localized()) \(reward) \("Coupons".localized())").font(.caption).foregroundColor(.orange)
            }
            Spacer()
            if current >= target {
                Label("Claimed".localized(), systemImage: "checkmark.seal.fill").foregroundColor(.green).font(.subheadline.bold())
            } else {
                VStack(alignment: .trailing) {
                    ProgressView(value: min(Double(current), Double(target)), total: Double(target))
                        .frame(width: 80).tint(.orange)
                    Text("\(current)/\(target) min").font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 服务器同步

    private func syncWithServer() {
        // 👇 修改 3：统一使用 currentUsername 检查，如果没有登录，重置界面数据并返回
        guard !currentUsername.isEmpty else {
            self.consecutiveDays = 0
            self.todayCheckedIn = false
            self.readingMinutes = 0
            self.isLoading = false
            return
        }
        
        isLoading = true
        Task {
            do {
                let status = try await APIService.shared.getWelfareStatus(username: currentUsername)
                
                await MainActor.run {
                    self.consecutiveDays = status.streak
                    self.todayCheckedIn = status.todayChecked
                    self.readingMinutes = status.readMins
                    self.isLoading = false
                }
            } catch {
                print("同步失败: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    private func handleCheckIn() {
        // 👇 新增 4：最核心的拦截！如果没登录，拉起弹窗并阻止后续接口调用
        guard !currentUsername.isEmpty else {
            showLoginView = true
            return
        }
        
        isLoading = true
        Task {
            do {
                let result = try await APIService.shared.submitCheckIn()
                await MainActor.run {
                    self.lastRewardAmount = result.reward
                    self.userBookCoupons = result.newTotal
                    self.todayCheckedIn = true
                    self.consecutiveDays += 1
                    self.isLoading = false
                    self.showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Already checked in today, come back tomorrow!".localized()
                    self.showErrorAlert = true
                }
            }
        }
    }
}
