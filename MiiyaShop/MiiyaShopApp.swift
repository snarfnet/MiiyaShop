import SwiftUI
import FirebaseCore

@main
struct MiiyaShopApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            CustomerView()
        }
    }
}
