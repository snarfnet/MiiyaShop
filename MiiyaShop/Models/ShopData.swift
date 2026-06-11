import Foundation
import SwiftUI
import FirebaseFirestore

enum ShopStatus: String, CaseIterable {
    case open = "open"
    case breakTime = "break"
    case closed = "closed"

    var label: String {
        switch self {
        case .open: return "営業中"
        case .breakTime: return "休憩中"
        case .closed: return "お休み"
        }
    }

    var emoji: String {
        switch self {
        case .open: return "🟢"
        case .breakTime: return "🟡"
        case .closed: return "🔴"
        }
    }
}

struct ShopInfo {
    var status: ShopStatus = .closed
    var message: String = ""
    var updatedAt: Date = Date()
}

struct TopNotice {
    var message: String = ""
    var updatedAt: Date = Date()
}

enum BusinessDayStatus: String, CaseIterable {
    case open = "open"
    case closed = "closed"

    var symbol: String {
        switch self {
        case .open: return "〇"
        case .closed: return "✖"
        }
    }

    var label: String {
        switch self {
        case .open: return "営業"
        case .closed: return "休み"
        }
    }

    var color: Color {
        switch self {
        case .open: return Color(red: 0.22, green: 0.58, blue: 0.32)
        case .closed: return Color(red: 0.82, green: 0.18, blue: 0.22)
        }
    }
}

enum BusinessCalendarKey {
    static func key(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct Product: Identifiable {
    var id: String = ""
    var name: String = ""
    var price: Int = 0
    var description: String = ""
    var imageBase64: String = ""
    var imageBase64List: [String] = []
    var order: Int = 0
    var isVisible: Bool = true

    var priceText: String {
        "¥\(price.formatted())"
    }

    var uiImage: UIImage? {
        guard let firstImageBase64 = imageBase64Values.first,
              !firstImageBase64.isEmpty,
              let data = Data(base64Encoded: firstImageBase64) else { return nil }
        return UIImage(data: data)
    }

    var uiImages: [UIImage] {
        imageBase64Values.compactMap { value in
            guard let data = Data(base64Encoded: value) else { return nil }
            return UIImage(data: data)
        }
    }

    var imageBase64Values: [String] {
        let list = imageBase64List.filter { !$0.isEmpty }
        if !list.isEmpty { return list }
        return imageBase64.isEmpty ? [] : [imageBase64]
    }
}

struct ShoppingMemoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date()
}

struct ContactMessage: Identifiable {
    var id: String = ""
    var name: String = ""
    var contact: String = ""
    var message: String = ""
    var isRead: Bool = false
    var createdAt: Date = Date()
}

struct ShopAnnouncement: Identifiable {
    var id: String = ""
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()
}

struct FeatureVisibility {
    var showAnnouncements: Bool = true
    var showStampCard: Bool = true
    var showShoppingMemo: Bool = true
    var showBusinessCalendar: Bool = true
    var showContactForm: Bool = true
}

struct StampConfig {
    var code: String = "MIIYA"
    var rewardText: String = "5スタンプで100円引きクーポン"
    var updatedAt: Date = Date()
}

struct StampCard: Codable, Equatable {
    var stampedDateKeys: [String] = []
    var redeemedCouponCount: Int = 0

    var totalStamps: Int {
        stampedDateKeys.count
    }

    var currentStamps: Int {
        totalStamps % 5
    }

    var earnedCouponCount: Int {
        totalStamps / 5
    }

    var availableCouponCount: Int {
        max(0, earnedCouponCount - redeemedCouponCount)
    }

    func hasStamp(for date: Date) -> Bool {
        stampedDateKeys.contains(BusinessCalendarKey.key(for: date))
    }
}
