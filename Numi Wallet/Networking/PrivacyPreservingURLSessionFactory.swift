import Foundation

enum PrivacyPreservingURLSessionFactory {
    static func make(timeout: TimeInterval = 20) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpAdditionalHeaders = [
            "Cache-Control": "no-store",
            "Pragma": "no-cache",
        ]
        return URLSession(configuration: configuration)
    }
}
