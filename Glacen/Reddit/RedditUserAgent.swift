import Foundation

enum RedditUserAgent {
    static var current: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        return "ios:com.kounex.glacen:v\(version) (by /u/glacen_app)"
    }
}
