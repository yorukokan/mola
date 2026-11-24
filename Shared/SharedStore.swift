import Foundation

/// Uygulama ve widget'ın ortak okuduğu kayıt dosyası (App Group klasöründe).
enum SharedStore {
    static var appGroupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "MolaAppGroup") as? String) ?? "group.com.okan.plaka.app"
    }

    static var directory: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        // App Group kurulmadıysa uygulama yine çalışsın (widget boş görünür)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Dosya adı eski sürümle aynı: kayıtlar kaybolmasın
    static var fileURL: URL { directory.appendingPathComponent("plaka-data.json") }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load() -> AppData {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(AppData.self, from: data) {
            return decoded
        }
        // Ana dosya bozulduysa yedeği dene
        let backup = directory.appendingPathComponent("plaka-data.backup.json")
        if let data = try? Data(contentsOf: backup),
           let decoded = try? decoder.decode(AppData.self, from: data) {
            return decoded
        }
        return AppData()
    }

    static func save(_ appData: AppData) {
        guard let data = try? encoder.encode(appData) else { return }
        let backup = directory.appendingPathComponent("plaka-data.backup.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
