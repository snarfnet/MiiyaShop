import SwiftUI

struct CustomerView: View {
    @StateObject private var service = ShopService()
    @State private var showAdminLogin = false
    @State private var showAdmin = false
    @State private var adminPassword = ""
    @State private var wrongPassword = false
    @State private var shoppingMemoItems: [ShoppingMemoItem] = []
    @State private var newMemoTitle = ""
    @State private var contactName = ""
    @State private var contactInfo = ""
    @State private var contactMessage = ""
    @State private var isSendingContact = false
    @State private var contactResultMessage = ""
    @State private var stampCard = StampCard()
    @State private var stampCodeInput = ""
    @State private var stampResultMessage = ""

    // Colors matching the mascot
    private let bgColor = Color(red: 0.98, green: 0.96, blue: 0.92)
    private let brownAccent = Color(red: 0.55, green: 0.38, blue: 0.22)
    private let leafGreen = Color(red: 0.25, green: 0.62, blue: 0.52)

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        mascotHeader

                        // Message
                        if !service.topNotice.message.isEmpty {
                            messageSection
                        }

                        if service.featureVisibility.showStampCard {
                            stampCardSection
                        }

                        if service.featureVisibility.showBusinessCalendar {
                            businessCalendarSection
                        }

                        if service.featureVisibility.showShoppingMemo {
                            shoppingMemoSection
                        }

                        if service.featureVisibility.showContactForm {
                            contactSection
                        }

                        // Products
                        if !service.products.isEmpty {
                            productsSection
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdmin) {
                AdminView(service: service)
            }
            .alert("管理画面", isPresented: $showAdminLogin) {
                SecureField("パスワード", text: $adminPassword)
                Button("入る") { loginAdmin() }
                Button("キャンセル", role: .cancel) { adminPassword = "" }
            } message: {
                Text(wrongPassword ? "パスワードが違います" : "パスワードを入力してください")
            }
            .task {
                await service.initializeIfNeeded()
                await service.enableAnnouncementNotifications()
            }
            .onAppear(perform: loadShoppingMemo)
            .onChange(of: shoppingMemoItems) { _ in
                saveShoppingMemo()
            }
            .onAppear(perform: loadStampCard)
            .onChange(of: stampCard) { _ in
                saveStampCard()
            }
        }
    }

    // MARK: - Mascot header (secret admin entry via 3s long press)
    private var mascotHeader: some View {
        VStack(spacing: 8) {
            mascotImage
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: mascotShadowColor.opacity(0.3), radius: 16, y: 4)
                .onLongPressGesture(minimumDuration: 3.0) {
                    openAdminLogin()
                }

            Text("雑貨屋みぃ～屋")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(brownAccent)
        }
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.4), value: service.shopInfo.status)
    }

    private var mascotImage: Image {
        switch service.shopInfo.status {
        case .open: return Image("mascot_open")
        case .breakTime: return Image("mascot_break")
        case .closed: return Image("mascot_closed")
        }
    }

    private var mascotShadowColor: Color {
        switch service.shopInfo.status {
        case .open: return .green
        case .breakTime: return .yellow
        case .closed: return .blue
        }
    }

    // MARK: - Message
    private var messageSection: some View {
        HStack {
            Image(systemName: "megaphone.fill")
                .foregroundColor(leafGreen)
            Text(service.topNotice.message)
                .font(.body)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(leafGreen.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(leafGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Business calendar
    private var businessCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(brownAccent)
                Text("営業カレンダー")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            BusinessCalendarView(days: service.businessDays)
        }
    }

    // MARK: - Stamp card
    private var stampCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "seal.fill")
                    .foregroundColor(brownAccent)
                Text("来店スタンプカード")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < visibleStampCount ? "star.circle.fill" : "circle")
                            .font(.system(size: 34))
                            .foregroundColor(index < visibleStampCount ? leafGreen : .secondary.opacity(0.45))
                    }
                }
                .frame(maxWidth: .infinity)

                Text(service.stampConfig.rewardText)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if stampCard.availableCouponCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("使えるクーポンがあります", systemImage: "ticket.fill")
                            .font(.body.weight(.bold))
                            .foregroundColor(leafGreen)
                        Text("会計時にこの画面を店主に見せてください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            redeemCoupon()
                        } label: {
                            Label("クーポンを使用済みにする", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(leafGreen.opacity(0.1)))
                }

                HStack(spacing: 8) {
                    TextField("店頭のスタンプコード", text: $stampCodeInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.done)
                        .onSubmit(addStamp)

                    Button(action: addStamp) {
                        Label("押す", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .disabled(stampCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !stampResultMessage.isEmpty {
                    Text(stampResultMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("来店時に店頭コードを入力すると、1日1回スタンプがたまります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.78)))
        }
    }

    // MARK: - Products
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(brownAccent)
                Text("本日のおすすめ商品")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            ForEach(service.products) { product in
                ProductCardView(
                    product: product,
                    accentColor: brownAccent,
                    onAddToMemo: memoAction(for: product)
                )
            }
        }
    }

    // MARK: - Shopping memo
    private var shoppingMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(brownAccent)
                Text("買い物メモ")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            HStack(spacing: 8) {
                TextField("探したい雑貨やメモ", text: $newMemoTitle)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addCustomMemo)

                Button(action: addCustomMemo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newMemoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if shoppingMemoItems.isEmpty {
                Text("気になる商品や探したいものをメモできます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.65)))
            } else {
                VStack(spacing: 8) {
                    ForEach($shoppingMemoItems) { $item in
                        HStack(spacing: 10) {
                            Button {
                                item.isDone.toggle()
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isDone ? leafGreen : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(item.isDone ? .secondary : .primary)
                                    .strikethrough(item.isDone)
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                removeMemoItem(item)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.75)))
                    }
                }
            }
        }
    }

    // MARK: - Contact
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(brownAccent)
                Text("お店に質問する")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            VStack(spacing: 10) {
                TextField("お名前", text: $contactName)
                    .textFieldStyle(.roundedBorder)
                TextField("連絡先（任意）", text: $contactInfo)
                    .textFieldStyle(.roundedBorder)
                TextField("質問内容", text: $contactMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)

                Button {
                    sendContactMessage()
                } label: {
                    HStack {
                        Spacer()
                        if isSendingContact {
                            ProgressView()
                        } else {
                            Label("送信", systemImage: "paperplane.fill")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(leafGreen)
                .disabled(isSendingContact || contactMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !contactResultMessage.isEmpty {
                    Text(contactResultMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.75)))
        }
    }

    // MARK: - Admin login
    private func openAdminLogin() {
        if let cachedPassword = AdminPasswordCache.load() {
            adminPassword = cachedPassword
            loginAdmin()
        } else {
            showAdminLogin = true
        }
    }

    private func loginAdmin() {
        Task {
            let ok = await service.checkPassword(adminPassword)
            if ok {
                AdminPasswordCache.save(adminPassword)
                adminPassword = ""
                wrongPassword = false
                showAdmin = true
            } else {
                AdminPasswordCache.delete()
                wrongPassword = true
                adminPassword = ""
                showAdminLogin = true
            }
        }
    }

    private func addCustomMemo() {
        let title = newMemoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        shoppingMemoItems.insert(ShoppingMemoItem(title: title), at: 0)
        newMemoTitle = ""
    }

    private func addProductToMemo(_ product: Product) {
        guard !shoppingMemoItems.contains(where: { $0.title == product.name }) else { return }
        shoppingMemoItems.insert(
            ShoppingMemoItem(title: product.name, note: product.priceText),
            at: 0
        )
    }

    private func memoAction(for product: Product) -> (() -> Void)? {
        guard service.featureVisibility.showShoppingMemo else { return nil }
        return {
            addProductToMemo(product)
        }
    }

    private func removeMemoItem(_ item: ShoppingMemoItem) {
        shoppingMemoItems.removeAll { $0.id == item.id }
    }

    private func loadShoppingMemo() {
        guard let data = UserDefaults.standard.data(forKey: "shoppingMemoItems"),
              let decoded = try? JSONDecoder().decode([ShoppingMemoItem].self, from: data) else { return }
        shoppingMemoItems = decoded
    }

    private func saveShoppingMemo() {
        guard let data = try? JSONEncoder().encode(shoppingMemoItems) else { return }
        UserDefaults.standard.set(data, forKey: "shoppingMemoItems")
    }

    private var visibleStampCount: Int {
        stampCard.availableCouponCount > 0 ? 5 : stampCard.currentStamps
    }

    private func loadStampCard() {
        guard let data = UserDefaults.standard.data(forKey: "stampCard"),
              let decoded = try? JSONDecoder().decode(StampCard.self, from: data) else { return }
        stampCard = decoded
    }

    private func saveStampCard() {
        guard let data = try? JSONEncoder().encode(stampCard) else { return }
        UserDefaults.standard.set(data, forKey: "stampCard")
    }

    private func addStamp() {
        guard service.isValidStampCode(stampCodeInput) else {
            stampResultMessage = "コードが違います。店頭のコードを確認してください。"
            return
        }
        let todayKey = BusinessCalendarKey.key(for: Date())
        guard !stampCard.stampedDateKeys.contains(todayKey) else {
            stampResultMessage = "今日のスタンプは取得済みです。"
            stampCodeInput = ""
            return
        }

        stampCard.stampedDateKeys.append(todayKey)
        stampCodeInput = ""
        if stampCard.currentStamps == 0 {
            stampResultMessage = "スタンプが5個たまりました。クーポンを使えます。"
        } else {
            stampResultMessage = "スタンプを追加しました。"
        }
    }

    private func redeemCoupon() {
        guard stampCard.availableCouponCount > 0 else { return }
        stampCard.redeemedCouponCount += 1
        stampResultMessage = "クーポンを使用済みにしました。"
    }

    private func sendContactMessage() {
        isSendingContact = true
        contactResultMessage = ""
        Task {
            let ok = await service.sendContactMessage(
                name: contactName,
                contact: contactInfo,
                message: contactMessage
            )
            isSendingContact = false
            if ok {
                contactName = ""
                contactInfo = ""
                contactMessage = ""
                contactResultMessage = "送信しました。"
            } else {
                contactResultMessage = "送信できませんでした。時間をおいてもう一度お試しください。"
            }
        }
    }
}
