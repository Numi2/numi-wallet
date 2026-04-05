import Foundation

extension Bundle {
    func url(forInfoDictionaryKey key: String) -> URL? {
        guard let rawValue = object(forInfoDictionaryKey: key) as? String,
              !rawValue.isEmpty else {
            return nil
        }
        return URL(string: rawValue)
    }

    func integer(forInfoDictionaryKey key: String, default defaultValue: Int) -> Int {
        if let rawValue = object(forInfoDictionaryKey: key) as? NSNumber {
            return rawValue.intValue
        }
        if let rawValue = object(forInfoDictionaryKey: key) as? String,
           let value = Int(rawValue) {
            return value
        }
        return defaultValue
    }

    func double(forInfoDictionaryKey key: String, default defaultValue: TimeInterval) -> TimeInterval {
        if let rawValue = object(forInfoDictionaryKey: key) as? NSNumber {
            return rawValue.doubleValue
        }
        if let rawValue = object(forInfoDictionaryKey: key) as? String,
           let value = TimeInterval(rawValue) {
            return value
        }
        return defaultValue
    }

    func bool(forInfoDictionaryKey key: String, default defaultValue: Bool) -> Bool {
        if let rawValue = object(forInfoDictionaryKey: key) as? NSNumber {
            return rawValue.boolValue
        }
        if let rawValue = object(forInfoDictionaryKey: key) as? String {
            switch rawValue.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                break
            }
        }
        return defaultValue
    }
}
