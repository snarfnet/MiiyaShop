import Foundation
import SwiftUI
import FirebaseFirestore

enum ShopStatus: String, CaseIterable {
    case open = "open"
    case closed = "closed"

    var label: String {
        switch self {
        case .open: return "営業中"
        case .closed: return "お休み"
        }
    }

    var emoji: String {
        switch self {
        case .open: return "🟢"
        case .closed: return "🔴"
        }
    }
}

struct ShopInfo {
    var status: ShopStatus = .closed
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
    var order: Int = 0
    var isVisible: Bool = true

    var priceText: String {
        "¥\(price.formatted())"
    }

    var uiImage: UIImage? {
        guard !imageBase64.isEmpty,
              let data = Data(base64Encoded: imageBase64) else { return nil }
        return UIImage(data: data)
    }
}
