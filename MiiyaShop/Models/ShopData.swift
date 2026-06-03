import Foundation
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

struct Product: Identifiable {
    var id: String = ""
    var name: String = ""
    var price: Int = 0
    var description: String = ""
    var imageURL: String = ""
    var order: Int = 0
    var isVisible: Bool = true

    var priceText: String {
        "¥\(price.formatted())"
    }
}
