import SwiftUI

@main
public struct SecureCallApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
