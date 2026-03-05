import SwiftUI

struct EditProfileView: View {
    @State var nickname: String
    @State var avatarUrl: String
    @Environment(\.dismiss) var dismiss
    
    // MARK: - 新增状态
    @State private var isSaving = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? // 用户选中的新图
    
    var body: some View {
        Form {
            Section(header: Text("Avatar".localized())) {
                HStack {
                    Spacer()
                    // 1. 头像显示区域
                    ZStack(alignment: .bottomTrailing) {
                        if let img = selectedImage {
                            // 显示刚选的本地图片
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            // 显示网络原图
                            AsyncImage(url: URL(string: avatarUrl)) { img in
                                img.resizable()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        }
                        
                        // 小相机图标
                        Image(systemName: "camera.fill")
                            .padding(6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .offset(x: 5, y: 5)
                    }
                    .onTapGesture {
                        // 2. 点击触发选择器
                        showImagePicker = true
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                HStack {
                    Spacer()
                    Text("Tap avatar to change".localized())
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            Section(header: Text("Basic Info".localized())) {
                HStack {
                    Text("Nickname".localized())
                    TextField("Enter new nickname".localized(), text: $nickname)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section {
                Button(action: saveChanges) {
                    if isSaving {
                        HStack {
                            ProgressView()
                            Text(" Saving...".localized())
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Changes".localized()).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || nickname.isEmpty)
            }
        }
        .navigationTitle("Edit Profile".localized())
        .hideTabBar()
        // 3. 挂载 Sheet 弹窗
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    private func saveChanges() {
        isSaving = true
        Task {
            var finalAvatarUrl = avatarUrl
            
            // A. 如果用户选了新图，先上传
            if let img = selectedImage {
                do {
                    if let uploadedUrl = try await APIService.shared.uploadImage(image: img) {
                        finalAvatarUrl = uploadedUrl
                    } else {
                        print("图片上传失败，服务端未返回 URL")
                        await MainActor.run { isSaving = false }
                        return
                    }
                } catch {
                    print("上传出错: \(error)")
                    await MainActor.run { isSaving = false }
                    return
                }
            }
            
            // B. 更新资料 (带上新头像 URL)
            do {
                let success = try await APIService.shared.updateProfile(newNickname: nickname, avatarUrl: finalAvatarUrl)
                if success {
                    UserDefaults.standard.set(nickname, forKey: "username")
                    await MainActor.run { dismiss() }
                }
            } catch {
                print("更新资料失败: \(error)")
            }
            
            await MainActor.run { isSaving = false }
        }
    }
}
