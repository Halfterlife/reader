import SwiftUI

struct LoginView: View {
    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    @State private var showRegister = false
    @State private var isAgreed = false

    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                Image(systemName: "book.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.yellow)
                    .padding(.top, 40)
                
                Text("Welcome Back".localized()).font(.title2).bold()

                VStack(spacing: 15) {
                    TextField("Account / Phone".localized(), text: $account)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                    
                    SecureField("Password".localized(), text: $password)
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

                Button(action: loginAction) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In".localized()).bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isLoading || account.isEmpty || password.isEmpty)
                
                Spacer()
                
                HStack {
                    Text("No account?".localized())
                    Button(action: { showRegister = true }) {
                        Text("Register Now".localized()).foregroundColor(.blue)
                    }
                }
                .font(.footnote)
                .padding(.bottom, 20)
            }
            .navigationTitle("Login".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) { isPresented = false }
                }
            }

            .sheet(isPresented: $showRegister) {
                RegisterView(isLoginViewPresented: $isPresented)
            }
            .alert("Login Failed".localized(), isPresented: $showError) {
                Button("OK".localized(), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    func loginAction() {
        if !isAgreed {
                    errorMessage = "Please read and agree to the User Agreement and Privacy Policy".localized()
                    showError = true
                    return
                }
        isLoading = true
        Task {
            do {
                let token = try await APIService.shared.login(username: account, password: password)
                await MainActor.run {
                    UserDefaults.standard.set(token, forKey: "user_token")
                    isLoggedIn = true
                    isLoading = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Incorrect account or password".localized()
                    showError = true
                }
            }
        }
    }
}
