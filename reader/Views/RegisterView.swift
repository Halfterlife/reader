import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    // 关键修改：接收来自 LoginView 的绑定
    @Binding var isLoginViewPresented: Bool
    
    @State private var account = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isAgreed = false

    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.yellow)
                    Text("Create Account".localized()).font(.title2).bold()
                }
                .padding(.top, 30)

                VStack(spacing: 15) {
                    TextField("Set Account".localized(), text: $account)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                    
                    SecureField("Set Password".localized(), text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Confirm Password".localized(), text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                HStack(spacing: 5) {
                                    Button(action: { isAgreed.toggle() }) {
                                        Image(systemName: isAgreed ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(isAgreed ? .yellow : .gray)
                                    }
                                    // iOS 15+ 支持直接在 Text 中使用 Markdown 语法识别链接
                    HStack(spacing: 0) {
                        Text("I have read and agree to ".localized())
                            .foregroundColor(.gray)
                        
                        Link("User Agreement".localized(), destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/terms.html")!)
                            .foregroundColor(.blue)
                        
                        Text(" and ".localized())
                            .foregroundColor(.gray)
                        
                        Link("Privacy Policy".localized(), destination: URL(string: "https://halfterlife.github.io/brightworld-entertainment/privacy.html")!)
                            .foregroundColor(.blue)
                    }
                    .font(.footnote)
                                        .foregroundColor(.gray)
                                        .tint(.blue) // 链接文字颜色
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                Button(action: registerAndLoginAction) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Register & Login".localized()).bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isLoading || account.isEmpty || password.isEmpty || confirmPassword.isEmpty)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel".localized()) { dismiss() }
                }
            }
            .alert("Operation Failed".localized(), isPresented: $showError) {
                Button("OK".localized(), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // 核心逻辑：注册成功后立即登录
    func registerAndLoginAction() {
        if !isAgreed {
                    errorMessage = "Please read and agree to the User Agreement and Privacy Policy".localized()
                    showError = true
                    return
                }
        
        if password != confirmPassword {
            errorMessage = "Passwords do not match".localized(); showError = true; return
        }
        
        isLoading = true
        Task {
            do {
                // 1. 注册
                let regSuccess = try await APIService.shared.register(username: account, password: password)
                
                if regSuccess {
                    // 2. 自动登录
                    let token = try await APIService.shared.login(username: account, password: password)
                    
                    await MainActor.run {
                        UserDefaults.standard.set(token, forKey: "user_token")
                        isLoggedIn = true // 更新全局登录状态
                        isLoading = false
                        
                        // 3. 关闭所有弹窗
                        dismiss() // 关闭注册 Sheet
                        isLoginViewPresented = false // 关闭底层登录弹窗
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Account already exists".localized(); showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Network request failed".localized(); showError = true
                }
            }
        }
    }
}
