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

    private let brownAccent = Color(red: 0.55, green: 0.38, blue: 0.22)

    var body: some View {
        NavigationStack {
            List {
                // Status section
                Section("営業ステータス") {
                    Picker("ステータス", selection: $selectedStatus) {
                        ForEach(ShopStatus.allCases, id: \.self) { status in
                            Text("\(status.emoji) \(status.label)").tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

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

                // Products section
                Section("おすすめ商品") {
                    ForEach(allProducts) { product in
                        Button {
                            editingProduct = product
                            showProductEditor = true
                        } label: {
                            HStack {
                                if !product.imageURL.isEmpty {
                                    AsyncImage(url: URL(string: product.imageURL)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
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
            .task {
                selectedStatus = service.shopInfo.status
                message = service.shopInfo.message
                allProducts = await service.fetchAllProducts()
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

    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = allProducts[index]
            Task {
                await service.deleteProduct(product)
                allProducts = await service.fetchAllProducts()
            }
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
                    } else if let url = product?.imageURL, !url.isEmpty {
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
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

        // Compress image
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
