import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
class ShopService: ObservableObject {
    @Published var shopInfo = ShopInfo()
    @Published var products: [Product] = []
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var statusListener: ListenerRegistration?
    private var productsListener: ListenerRegistration?

    static let adminPasswordKey = "miiya_admin_pw"
    static let defaultPassword = "miiya2026"

    init() {
        listenToStatus()
        listenToProducts()
    }

    deinit {
        statusListener?.remove()
        productsListener?.remove()
    }

    // MARK: - Listeners (real-time updates)

    private func listenToStatus() {
        statusListener = db.collection("config").document("shopStatus")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let data = snapshot?.data() else { return }
                self.shopInfo.status = ShopStatus(rawValue: data["status"] as? String ?? "closed") ?? .closed
                self.shopInfo.message = data["message"] as? String ?? ""
                if let ts = data["updatedAt"] as? Timestamp {
                    self.shopInfo.updatedAt = ts.dateValue()
                }
                self.isLoading = false
            }
    }

    private func listenToProducts() {
        productsListener = db.collection("products")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                self.products = docs.compactMap { doc in
                    let d = doc.data()
                    guard d["isVisible"] as? Bool ?? true else { return nil }
                    return Product(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "",
                        price: d["price"] as? Int ?? 0,
                        description: d["description"] as? String ?? "",
                        imageURL: d["imageURL"] as? String ?? "",
                        order: d["order"] as? Int ?? 0,
                        isVisible: d["isVisible"] as? Bool ?? true
                    )
                }
            }
    }

    // MARK: - Admin: Status

    func updateStatus(_ status: ShopStatus, message: String) async {
        do {
            try await db.collection("config").document("shopStatus").setData([
                "status": status.rawValue,
                "message": message,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("Status update error: \(error)")
        }
    }

    // MARK: - Admin: Products

    func fetchAllProducts() async -> [Product] {
        do {
            let snapshot = try await db.collection("products").order(by: "order").getDocuments()
            return snapshot.documents.map { doc in
                let d = doc.data()
                return Product(
                    id: doc.documentID,
                    name: d["name"] as? String ?? "",
                    price: d["price"] as? Int ?? 0,
                    description: d["description"] as? String ?? "",
                    imageURL: d["imageURL"] as? String ?? "",
                    order: d["order"] as? Int ?? 0,
                    isVisible: d["isVisible"] as? Bool ?? true
                )
            }
        } catch {
            return []
        }
    }

    func saveProduct(_ product: Product, imageData: Data?) async -> Bool {
        do {
            var data: [String: Any] = [
                "name": product.name,
                "price": product.price,
                "description": product.description,
                "imageURL": product.imageURL,
                "order": product.order,
                "isVisible": product.isVisible
            ]

            if let imageData {
                let url = try await uploadImage(imageData, productId: product.id.isEmpty ? UUID().uuidString : product.id)
                data["imageURL"] = url
            }

            if product.id.isEmpty {
                try await db.collection("products").addDocument(data: data)
            } else {
                try await db.collection("products").document(product.id).setData(data)
            }
            return true
        } catch {
            print("Save product error: \(error)")
            return false
        }
    }

    func deleteProduct(_ product: Product) async {
        guard !product.id.isEmpty else { return }
        do {
            try await db.collection("products").document(product.id).delete()
            if !product.imageURL.isEmpty {
                try? await storage.reference(forURL: product.imageURL).delete()
            }
        } catch {
            print("Delete error: \(error)")
        }
    }

    // MARK: - Image upload

    private func uploadImage(_ data: Data, productId: String) async throws -> String {
        let ref = storage.reference().child("products/\(productId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    // MARK: - Admin password

    func checkPassword(_ input: String) async -> Bool {
        do {
            let doc = try await db.collection("config").document("admin").getDocument()
            let stored = doc.data()?["password"] as? String ?? ShopService.defaultPassword
            return input == stored
        } catch {
            return input == ShopService.defaultPassword
        }
    }

    func updatePassword(_ newPassword: String) async {
        try? await db.collection("config").document("admin").setData([
            "password": newPassword
        ], merge: true)
    }

    func initializeIfNeeded() async {
        let doc = try? await db.collection("config").document("shopStatus").getDocument()
        if doc?.exists != true {
            try? await db.collection("config").document("shopStatus").setData([
                "status": "closed",
                "message": "",
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
        let adminDoc = try? await db.collection("config").document("admin").getDocument()
        if adminDoc?.exists != true {
            try? await db.collection("config").document("admin").setData([
                "password": ShopService.defaultPassword
            ])
        }
    }
}
