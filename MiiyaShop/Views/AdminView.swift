import SwiftUI
import PhotosUI

struct AdminView: View {
    @ObservedObject var service: ShopService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStatus: ShopStatus = .closed
    @State private var message = ""
    @State private var allProducts: [Product] = []
    @State private var showProductEditor = false
    @State private var editingProduct: Product?
    @State private var isSaving = false
    @State private var showPasswordChange = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError = ""
    @State private var announcementTitle = ""
    @State private var announcementBody = ""
    @State private var isSendingAnnouncement = false
    @State private var announcementResult = ""
    @State private var stampCode = ""
    @State private var stampRewardText = ""
    @State private var isSavingStampConfig = false
    @State private var stampConfigResult = ""

    private let brownAccent = Color(red: 0.55, green: 0.38, blue: 0.22)

    var body: some View {
        NavigationStack {
            List {
                // Status section
                Section("営業ステータス") {
                    ForEach(ShopStatus.allCases, id: \.self) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            HStack {
                                Text("\(status.emoji) \(status.label)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedStatus == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    TextField("お知らせメッセージ（任意）", text: $message, axis: .vertical)
                        .lineLimit(3)

                    Button {
                        saveStatus()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("ステータスを更新")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }

                Section("営業カレンダー") {
                    BusinessCalendarView(
                        days: service.businessDays,
                        isEditable: true,
                        onTapDate: toggleBusinessDay
                    )

                    Text("日付をタップすると、未設定、〇、✖の順に切り替わります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("来店スタンプカード") {
                    Text("現在のコード: \(service.stampConfig.code)")
                        .font(.body.weight(.semibold))

                    TextField("店頭で案内するコード", text: $stampCode)
                        .textInputAutocapitalization(.characters)

                    TextField("クーポン内容", text: $stampRewardText, axis: .vertical)
                        .lineLimit(2)

                    Button {
                        saveStampConfig()
                    } label: {
                        HStack {
                            Spacer()
                            if isSavingStampConfig {
                                ProgressView()
                            } else {
                                Label("スタンプ設定を保存", systemImage: "seal")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSavingStampConfig)

                    if !stampConfigResult.isEmpty {
                        Text(stampConfigResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("お客さんは店頭コードを入力すると、1日1回スタンプを取得できます。5個でクーポン表示になります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("質問受信箱") {
                    if service.contactMessages.isEmpty {
                        Text("まだ質問は届いていません。")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(service.contactMessages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(message.name)
                                        .font(.body.weight(.bold))
                                    Spacer()
                                    Text(message.isRead ? "既読" : "未読")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(message.isRead ? .gray : .orange)
                                        .clipShape(Capsule())
                                }

                                if !message.contact.isEmpty {
                                    Label(message.contact, systemImage: "person.crop.circle.badge.questionmark")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(message.message)
                                    .font(.body)

                                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Button(message.isRead ? "未読に戻す" : "既読にする") {
                                        Task { await service.setContactMessageRead(message, isRead: !message.isRead) }
                                    }
                                    Spacer()
                                    Button("削除", role: .destructive) {
                                        Task { await service.deleteContactMessage(message) }
                                    }
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section("一斉お知らせ") {
                    TextField("タイトル", text: $announcementTitle)
                    TextField("本文", text: $announcementBody, axis: .vertical)
                        .lineLimit(3)

                    Button {
                        sendAnnouncement()
                    } label: {
                        HStack {
                            Spacer()
                            if isSendingAnnouncement {
                                ProgressView()
                            } else {
                                Label("お知らせを送信", systemImage: "bell.badge")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(
                        isSendingAnnouncement ||
                        announcementTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        announcementBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if !announcementResult.isEmpty {
                        Text(announcementResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !service.announcements.isEmpty {
                        ForEach(service.announcements.prefix(5)) { announcement in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(announcement.title)
                                    .font(.body.weight(.bold))
                                Text(announcement.body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text(announcement.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("削除", role: .destructive) {
                                        Task { await service.deleteAnnouncement(announcement) }
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }

                // Products section
                Section("おすすめ商品") {
                    ForEach(allProducts) { product in
                        Button {
                            editingProduct = product
                            showProductEditor = true
                        } label: {
                            HStack {
                                if let img = product.uiImage {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .foregroundColor(.primary)
                                    Text(product.priceText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if !product.isVisible {
                                    Text("非表示")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.gray)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteProducts)

                    if allProducts.count < 5 {
                        Button {
                            editingProduct = nil
                            showProductEditor = true
                        } label: {
                            Label("商品を追加", systemImage: "plus")
                        }
                    }
                }

                // Settings section
                Section("設定") {
                    Button {
                        showPasswordChange = true
                    } label: {
                        Label("パスワード変更", systemImage: "lock.rotation")
                    }
                }
            }
            .navigationTitle("管理画面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showProductEditor) {
                ProductEditorView(
                    service: service,
                    product: editingProduct,
                    nextOrder: allProducts.count
                ) {
                    Task { allProducts = await service.fetchAllProducts() }
                }
            }
            .alert("パスワード変更", isPresented: $showPasswordChange) {
                SecureField("新しいパスワード", text: $newPassword)
                SecureField("もう一度入力", text: $confirmPassword)
                Button("変更") { changePassword() }
                Button("キャンセル", role: .cancel) {
                    newPassword = ""
                    confirmPassword = ""
                }
            } message: {
                Text(passwordError.isEmpty ? "新しいパスワードを入力してください" : passwordError)
            }
            .task {
                selectedStatus = service.shopInfo.status
                message = service.shopInfo.message
                allProducts = await service.fetchAllProducts()
                stampCode = service.stampConfig.code
                stampRewardText = service.stampConfig.rewardText
                await service.enableContactMessageNotifications()
            }
        }
    }

    private func saveStatus() {
        isSaving = true
        Task {
            await service.updateStatus(selectedStatus, message: message)
            isSaving = false
        }
    }

    private func toggleBusinessDay(_ date: Date) {
        let nextStatus: BusinessDayStatus?
        switch service.status(for: date) {
        case .none:
            nextStatus = .open
        case .some(.open):
            nextStatus = .closed
        case .some(.closed):
            nextStatus = nil
        }

        Task {
            await service.updateBusinessDay(date, status: nextStatus)
        }
    }

    private func sendAnnouncement() {
        isSendingAnnouncement = true
        announcementResult = ""
        Task {
            let ok = await service.sendAnnouncement(title: announcementTitle, body: announcementBody)
            isSendingAnnouncement = false
            if ok {
                announcementTitle = ""
                announcementBody = ""
                announcementResult = "送信しました。"
            } else {
                announcementResult = "送信できませんでした。"
            }
        }
    }

    private func saveStampConfig() {
        isSavingStampConfig = true
        stampConfigResult = ""
        let code = stampCode.isEmpty ? service.stampConfig.code : stampCode
        let reward = stampRewardText.isEmpty ? service.stampConfig.rewardText : stampRewardText

        Task {
            let ok = await service.updateStampConfig(code: code, rewardText: reward)
            isSavingStampConfig = false
            if ok {
                stampCode = code.uppercased()
                stampRewardText = reward
                stampConfigResult = "保存しました。"
            } else {
                stampConfigResult = "保存できませんでした。"
            }
        }
    }

    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = allProducts[index]
            Task {
                await service.deleteProduct(product)
                allProducts = await service.fetchAllProducts()
            }
        }
    }

    private func changePassword() {
        guard !newPassword.isEmpty else {
            passwordError = "パスワードを入力してください"
            showPasswordChange = true
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = "パスワードが一致しません"
            newPassword = ""
            confirmPassword = ""
            showPasswordChange = true
            return
        }
        Task {
            await service.updatePassword(newPassword)
            newPassword = ""
            confirmPassword = ""
            passwordError = ""
        }
    }
}

// MARK: - Product editor
struct ProductEditorView: View {
    @ObservedObject var service: ShopService
    let product: Product?
    let nextOrder: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var price = ""
    @State private var description = ""
    @State private var isVisible = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var previewImage: UIImage?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("商品情報") {
                    TextField("商品名", text: $name)
                    TextField("価格（数字のみ）", text: $price)
                        .keyboardType(.numberPad)
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .lineLimit(3)
                    Toggle("お客さんに表示", isOn: $isVisible)
                }

                Section("写真") {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let img = product?.uiImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("写真を選択", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .navigationTitle(product == nil ? "商品追加" : "商品編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存").fontWeight(.semibold)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                        previewImage = UIImage(data: data)
                    }
                }
            }
            .onAppear {
                if let p = product {
                    name = p.name
                    price = String(p.price)
                    description = p.description
                    isVisible = p.isVisible
                }
            }
        }
    }

    private func save() {
        isSaving = true
        var p = product ?? Product()
        p.name = name
        p.price = Int(price) ?? 0
        p.description = description
        p.isVisible = isVisible
        if product == nil { p.order = nextOrder }

        var compressed: Data?
        if let imageData, let img = UIImage(data: imageData) {
            compressed = img.jpegData(compressionQuality: 0.7)
        }

        Task {
            let ok = await service.saveProduct(p, imageData: compressed)
            if ok {
                onSave()
                dismiss()
            }
            isSaving = false
        }
    }
}
