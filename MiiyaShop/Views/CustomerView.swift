import SwiftUI

struct CustomerView: View {
    @StateObject private var service = ShopService()
    @State private var showAdminLogin = false
    @State private var showAdmin = false
    @State private var adminPassword = ""
    @State private var wrongPassword = false

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
                        // Mascot logo (long press = admin)
                        mascotHeader

                        // Status badge
                        statusSection

                        // Message
                        if !service.shopInfo.message.isEmpty {
                            messageSection
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
            }
        }
    }

    // MARK: - Mascot header (secret admin entry)
    private var mascotHeader: some View {
        VStack(spacing: 8) {
            Image("mascot")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onLongPressGesture(minimumDuration: 3.0) {
                    showAdminLogin = true
                }

            Text("雑貨屋みぃ～屋")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(brownAccent)
        }
        .padding(.top, 8)
    }

    // MARK: - Status
    private var statusSection: some View {
        HStack(spacing: 12) {
            Text(service.shopInfo.status.emoji)
                .font(.system(size: 32))

            Text(service.shopInfo.status.label)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(statusColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: statusColor.opacity(0.2), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.4), lineWidth: 2)
        )
    }

    private var statusColor: Color {
        switch service.shopInfo.status {
        case .open: return .green
        case .preparing: return .orange
        case .closed: return .gray
        }
    }

    // MARK: - Message
    private var messageSection: some View {
        HStack {
            Image(systemName: "megaphone.fill")
                .foregroundColor(leafGreen)
            Text(service.shopInfo.message)
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

    // MARK: - Products
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(brownAccent)
                Text("おすすめ商品")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brownAccent)
            }

            ForEach(service.products) { product in
                ProductCardView(product: product, accentColor: brownAccent)
            }
        }
    }

    // MARK: - Admin login
    private func loginAdmin() {
        Task {
            let ok = await service.checkPassword(adminPassword)
            if ok {
                adminPassword = ""
                wrongPassword = false
                showAdmin = true
            } else {
                wrongPassword = true
                adminPassword = ""
                showAdminLogin = true
            }
        }
    }
}
