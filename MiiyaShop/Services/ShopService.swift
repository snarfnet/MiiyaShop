import Foundation
import FirebaseFirestore
import SwiftUI
import UserNotifications

@MainActor
class ShopService: ObservableObject {
    @Published var shopInfo = ShopInfo()
    @Published var topNotice = TopNotice()
    @Published var products: [Product] = []
    @Published var businessDays: [String: BusinessDayStatus] = [:]
    @Published var contactMessages: [ContactMessage] = []
    @Published var announcements: [ShopAnnouncement] = []
    @Published var stampConfig = StampConfig()
    @Published var featureVisibility = FeatureVisibility()
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var statusListener: ListenerRegistration?
    private var topNoticeListener: ListenerRegistration?
    private var productsListener: ListenerRegistration?
    private var calendarListener: ListenerRegistration?
    private var contactMessagesListener: ListenerRegistration?
    private var announcementsListener: ListenerRegistration?
    private var stampConfigListener: ListenerRegistration?
    private var featureVisibilityListener: ListenerRegistration?
    private var knownContactMessageIds = Set<String>()
    private var knownAnnouncementIds = Set<String>()
    private var didLoadContactMessages = false
    private var didLoadAnnouncements = false
    private var shouldNotifyContactMessages = false
    private var shouldNotifyAnnouncements = false

    static let defaultPassword = "miiya2026"

    init() {
        listenToStatus()
        listenToTopNotice()
        listenToProducts()
        listenToCalendar()
        listenToContactMessages()
        listenToAnnouncements()
        listenToStampConfig()
        listenToFeatureVisibility()
    }

    deinit {
        statusListener?.remove()
        topNoticeListener?.remove()
        productsListener?.remove()
        calendarListener?.remove()
        contactMessagesListener?.remove()
        announcementsListener?.remove()
        stampConfigListener?.remove()
        featureVisibilityListener?.remove()
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

    private func listenToTopNotice() {
        topNoticeListener = db.collection("config").document("topNotice")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                self.topNotice.message = data["message"] as? String ?? ""
                if let ts = data["updatedAt"] as? Timestamp {
                    self.topNotice.updatedAt = ts.dateValue()
                }
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

    private func listenToContactMessages() {
        contactMessagesListener = db.collection("contactMessages")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                let incomingMessages = docs.map { doc in
                    let data = doc.data()
                    return ContactMessage(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "",
                        contact: data["contact"] as? String ?? "",
                        message: data["message"] as? String ?? "",
                        isRead: data["isRead"] as? Bool ?? false,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                let incomingIds = Set(incomingMessages.map(\.id))
                if self.didLoadContactMessages, self.shouldNotifyContactMessages {
                    for message in incomingMessages where !message.isRead && !self.knownContactMessageIds.contains(message.id) {
                        self.notifyNewContactMessage(message)
                    }
                }
                self.knownContactMessageIds = incomingIds
                self.didLoadContactMessages = true
                self.contactMessages = incomingMessages
            }
    }

    private func listenToAnnouncements() {
        announcementsListener = db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                let incoming = docs.map { doc in
                    let data = doc.data()
                    return ShopAnnouncement(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                let incomingIds = Set(incoming.map(\.id))
                if self.didLoadAnnouncements, self.shouldNotifyAnnouncements {
                    for announcement in incoming where !self.knownAnnouncementIds.contains(announcement.id) {
                        self.notifyAnnouncement(announcement)
                    }
                }
                self.knownAnnouncementIds = incomingIds
                self.didLoadAnnouncements = true
                self.announcements = incoming
            }
    }

    private func listenToStampConfig() {
        stampConfigListener = db.collection("config").document("stampCard")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                self.stampConfig = StampConfig(
                    code: data["code"] as? String ?? "MIIYA",
                    rewardText: data["rewardText"] as? String ?? "5スタンプで100円引きクーポン",
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
    }

    private func listenToFeatureVisibility() {
        featureVisibilityListener = db.collection("config").document("featureVisibility")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                self.featureVisibility = FeatureVisibility(
                    showAnnouncements: data["showAnnouncements"] as? Bool ?? true,
                    showStampCard: data["showStampCard"] as? Bool ?? true,
                    showShoppingMemo: data["showShoppingMemo"] as? Bool ?? true,
                    showBusinessCalendar: data["showBusinessCalendar"] as? Bool ?? true,
                    showContactForm: data["showContactForm"] as? Bool ?? true
                )
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

    func updateTopNotice(_ message: String) async -> Bool {
        do {
            try await db.collection("config").document("topNotice").setData([
                "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return true
        } catch {
            print("Top notice update error: \(error)")
            return false
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

    // MARK: - Contact messages

    func sendContactMessage(name: String, contact: String, message: String) async -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return false }

        do {
            try await db.collection("contactMessages").addDocument(data: [
                "name": cleanName.isEmpty ? "お客さま" : cleanName,
                "contact": cleanContact,
                "message": cleanMessage,
                "isRead": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            print("Contact message error: \(error)")
            return false
        }
    }

    func setContactMessageRead(_ message: ContactMessage, isRead: Bool) async {
        guard !message.id.isEmpty else { return }
        do {
            try await db.collection("contactMessages").document(message.id).setData([
                "isRead": isRead
            ], merge: true)
        } catch {
            print("Contact read update error: \(error)")
        }
    }

    func deleteContactMessage(_ message: ContactMessage) async {
        guard !message.id.isEmpty else { return }
        do {
            try await db.collection("contactMessages").document(message.id).delete()
        } catch {
            print("Contact delete error: \(error)")
        }
    }

    // MARK: - Announcements

    func sendAnnouncement(title: String, body: String) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else { return false }

        do {
            try await db.collection("announcements").addDocument(data: [
                "title": cleanTitle,
                "body": cleanBody,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            print("Announcement send error: \(error)")
            return false
        }
    }

    func deleteAnnouncement(_ announcement: ShopAnnouncement) async {
        guard !announcement.id.isEmpty else { return }
        do {
            try await db.collection("announcements").document(announcement.id).delete()
        } catch {
            print("Announcement delete error: \(error)")
        }
    }

    // MARK: - Stamp card

    func updateStampConfig(code: String, rewardText: String) async -> Bool {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanReward = rewardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty, !cleanReward.isEmpty else { return false }

        do {
            try await db.collection("config").document("stampCard").setData([
                "code": cleanCode,
                "rewardText": cleanReward,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return true
        } catch {
            print("Stamp config update error: \(error)")
            return false
        }
    }

    func isValidStampCode(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == stampConfig.code.uppercased()
    }

    // MARK: - Feature visibility

    func updateFeatureVisibility(_ visibility: FeatureVisibility) async -> Bool {
        do {
            try await db.collection("config").document("featureVisibility").setData([
                "showAnnouncements": visibility.showAnnouncements,
                "showStampCard": visibility.showStampCard,
                "showShoppingMemo": visibility.showShoppingMemo,
                "showBusinessCalendar": visibility.showBusinessCalendar,
                "showContactForm": visibility.showContactForm,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return true
        } catch {
            print("Feature visibility update error: \(error)")
            return false
        }
    }

    func enableContactMessageNotifications() async {
        do {
            shouldNotifyContactMessages = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            shouldNotifyContactMessages = false
            print("Notification permission error: \(error)")
        }
    }

    func enableAnnouncementNotifications() async {
        do {
            shouldNotifyAnnouncements = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            shouldNotifyAnnouncements = false
            print("Announcement notification permission error: \(error)")
        }
    }

    private func notifyNewContactMessage(_ message: ContactMessage) {
        let content = UNMutableNotificationContent()
        content.title = "新しい質問が届きました"
        content.body = "\(message.name): \(message.message)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "contact-\(message.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notifyAnnouncement(_ announcement: ShopAnnouncement) {
        let content = UNMutableNotificationContent()
        content.title = announcement.title
        content.body = announcement.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "announcement-\(announcement.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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

    func updatePassword(_ newPassword: String) async -> Bool {
        do {
            try await db.collection("config").document("admin").setData([
                "password": newPassword
            ], merge: true)
            return true
        } catch {
            print("Password update error: \(error)")
            return false
        }
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
        let topNoticeDoc = try? await db.collection("config").document("topNotice").getDocument()
        if topNoticeDoc?.exists != true {
            try? await db.collection("config").document("topNotice").setData([
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
        let stampDoc = try? await db.collection("config").document("stampCard").getDocument()
        if stampDoc?.exists != true {
            try? await db.collection("config").document("stampCard").setData([
                "code": "MIIYA",
                "rewardText": "5スタンプで100円引きクーポン",
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
        let visibilityDoc = try? await db.collection("config").document("featureVisibility").getDocument()
        if visibilityDoc?.exists != true {
            try? await db.collection("config").document("featureVisibility").setData([
                "showAnnouncements": true,
                "showStampCard": true,
                "showShoppingMemo": true,
                "showBusinessCalendar": true,
                "showContactForm": true,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }
}
