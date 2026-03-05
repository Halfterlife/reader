import SwiftUI

struct FeedbackView: View {
    @State private var content: String = ""
    @State private var contact: String = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) var dismiss // 用于返回上一页
    
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    @State private var showSuccessAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Feedback Content".localized())) {
                TextEditor(text: $content)
                    .frame(height: 150)
                    .overlay(
                        Text(content.isEmpty ? "Please describe your issue or suggestion...".localized() : "")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 5),
                        alignment: .topLeading
                    )
            }
            
            Section(header: Text("Contact Info (Optional)".localized())) {
                TextField("Phone / Email / WeChat".localized(), text: $contact)
            }
            
            Button(action: submitFeedback) {
                if isSubmitting {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Text("Submit Feedback".localized()).frame(maxWidth: .infinity)
                }
            }
            .disabled(content.isEmpty || isSubmitting)
        }
        .navigationTitle("Feedback".localized())
        .hideTabBar()
        // 错误提示弹窗
        .alert("Submission Alert".localized(), isPresented: $showErrorAlert) {
            Button("OK".localized(), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Submission Successful".localized(), isPresented: $showSuccessAlert) {
            // 点击确定后执行 dismiss() 返回上一页
            Button("Confirm".localized(), role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Thank you for your feedback, we will process it soon.".localized())
        }
    }
    
    func submitFeedback() {
        print("开始提交反馈...")
        isSubmitting = true
        
        Task {
            do {
                // 调用 API
                let success = try await APIService.shared.postFeedback(content: content, contact: contact)
                
                await MainActor.run {
                    isSubmitting = false
                    if success {
                        print("反馈提交成功，弹出提示框")
                        showSuccessAlert = true
                    } else {
                        print("提交失败：服务器返回 false")
                        errorMessage = "Submission failed, server not responding.".localized()
                        showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("提交报错: \(error)")
                    errorMessage = "\("Error occurred: ".localized())\(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}
