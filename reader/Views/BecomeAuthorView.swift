
import SwiftUI

struct BecomeAuthorView: View {
    @State private var realName = ""
    @State private var contact = ""
    @State private var intro = ""
    @State private var isSubmitting = false
    @State private var showToast = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Section(header: Text("Basic Info".localized())) {
                TextField("Real Name".localized(), text: $realName)
                TextField("Contact (WeChat/Phone)".localized(), text: $contact)
            }
            
            Section(header: Text("Writing Experience".localized())) {
                TextEditor(text: $intro)
                    .frame(height: 100)
                    .overlay(
                        Text(intro.isEmpty ? "Briefly introduce your writing experience...".localized() : "")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.leading, 5)
                            .padding(.top, 8),
                        alignment: .topLeading
                    )
            }
            
            Button(action: submitApplication) {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Application".localized())
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
            }
            .disabled(realName.isEmpty || contact.isEmpty || isSubmitting)
        }
        .navigationTitle("Become an Author".localized())
        .hideTabBar()
        .alert("Submission Successful".localized(), isPresented: $showToast) {
            Button("OK".localized()) { presentationMode.wrappedValue.dismiss() }
        } message: {
            Text("Your application has been sent. The admin will contact you soon.".localized())
        }
    }
    
    func submitApplication() {
        isSubmitting = true
        Task {
            do {
                let success = try await APIService.shared.applyAuthor(realName: realName, contact: contact, intro: intro)
                await MainActor.run {
                    isSubmitting = false
                    if success { showToast = true }
                }
            } catch {
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}
