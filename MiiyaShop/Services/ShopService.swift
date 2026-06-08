import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class ShopService: ObservableObject {
    @Published var shopInfo = ShopInfo()
    @Published var products: [Product] = []
    @Published var businessDays: [String: BusinessDayStatus] = [:]
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var statusListener: ListenerRegistration?
    private var productsListener: ListenerRegistration?
    private var calendarListener: ListenerRegistration?

    static let defaultPassword = "miiya2026"

    init() {
        listenToStatus()
        listenToProducts()
        listenToCalendar()
    }

    deinit {
        statusListener?.remove()
        productsListener?.remove()
        calendarListener?.remove()
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
                        imageBase64: d["imageBase64"] as? String ?? "",
                        order: d["order"] as? Int ?? 0,
                        isVisible: d["isVisible"] as? Bool ?? true
                    )
                }
            }
    }

    private func listenToCalendar() {
        calendarListener = db.collection("config").document("businessCalendar")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                let rawDays = snapshot?.data()?["days"] as? [String: String] ?? [:]
                self.businessDays = rawDays.reduce(into: [:]) { result, item in
                    if let status = BusinessDayStatus(rawValue: item.value) {
                        result[item.key] = status
                    }
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

    // MARK: - Admin: Business calendar

    func status(for date: Date) -> BusinessDayStatus? {
        businessDays[BusinessCalendarKey.key(for: date)]
    }

    func updateBusinessDay(_ date: Date, status: BusinessDayStatus?) async {
        let key = BusinessCalendarKey.key(for: date)
        var updatedDays = businessDays
        updatedDays[key] = status
        let rawDays = updatedDays.mapValues(\.rawValue)

        do {
            try await db.collection("config").document("businessCalendar").setData([
                "days": rawDays,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Calendar update error: \(error)")
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
                    imageBase64: d["imageBase64"] as? String ?? "",
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
                "order": product.order,
                "isVisible": product.isVisible
            ]

            if let imageData {
                data["imageBase64"] = imageData.base64EncodedString()
            } else {
                data["imageBase64"] = product.imageBase64
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
        } catch {
            print("Delete error: \(error)")
        }
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
        let calendarDoc = try? await db.collection("config").document("businessCalendar").getDocument()
        if calendarDoc?.exists != true {
            try? await db.collection("config").document("businessCalendar").setData([
                "days": [String: String](),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }
}
