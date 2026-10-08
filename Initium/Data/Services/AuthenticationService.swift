import Foundation
import Security

enum AuthenticationState: Equatable, Sendable {
    case restoring
    case loggedOut
    case loggedIn
}

struct AuthenticatedUser: Codable, Equatable, Sendable {
    let id: UUID
    let email: String
}

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String?
    var preferredLocale: String?
    var onboardingCompleted: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case preferredLocale = "preferred_locale"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct StoredAuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: AuthenticatedUser
}

enum AuthenticationError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidCredentials
    case emailAlreadyRegistered
    case weakPassword
    case network
    case rateLimited
    case sessionUnavailable
    case profileUnavailable
    case accountDeletionFailed
    case unknown

    var localizationKey: String {
        switch self {
        case .invalidConfiguration: "auth.error.configuration"
        case .invalidCredentials: "auth.error.invalid_credentials"
        case .emailAlreadyRegistered: "auth.error.email_registered"
        case .weakPassword: "auth.error.weak_password"
        case .network: "auth.error.network"
        case .rateLimited: "auth.error.rate_limited"
        case .sessionUnavailable: "auth.error.session_unavailable"
        case .profileUnavailable: "auth.error.profile_unavailable"
        case .accountDeletionFailed: "auth.error.delete_account"
        case .unknown: "auth.error.generic"
        }
    }
}

protocol AuthSessionStoring: AnyObject {
    func load() throws -> StoredAuthSession?
    func save(_ session: StoredAuthSession) throws
    func clear() throws
}

@MainActor
protocol AuthenticationServicing: AnyObject {
    var state: AuthenticationState { get }
    var profile: UserProfile? { get }
    var currentUser: AuthenticatedUser? { get }
    func restoreSession() async
    func signUp(email: String, password: String, displayName: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async
    func sendPasswordReset(email: String) async throws
    func fetchProfile() async throws -> UserProfile
    func updateProfile(displayName: String, preferredLocale: String) async throws -> UserProfile
    func updatePassword(_ password: String) async throws
    func deleteAccount() async throws
}

final class KeychainAuthSessionStore: AuthSessionStoring {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.guillaumelsx.initium",
        account: String = "supabase.auth.session"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> StoredAuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AuthenticationError.unknown
        }

        return try JSONDecoder().decode(StoredAuthSession.self, from: data)
    }

    func save(_ session: StoredAuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = baseQuery
            attributes.forEach { item[$0.key] = $0.value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw AuthenticationError.unknown
            }
        } else if updateStatus != errSecSuccess {
            throw AuthenticationError.unknown
        }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.unknown
        }
    }
}

@MainActor
final class AuthenticationService: ObservableObject, AuthenticationServicing {
    static let passwordResetRedirectURL = "initium://auth/callback"

    @Published private(set) var state: AuthenticationState = .restoring
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isPasswordRecoveryActive = false

    private let configuration: SupabaseConfiguration?
    private let sessionStore: AuthSessionStoring
    private let session: URLSession
    private var currentSession: StoredAuthSession?

    init(
        configuration: SupabaseConfiguration? = SupabaseConfiguration.fromBundle(),
        sessionStore: AuthSessionStoring = KeychainAuthSessionStore(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.sessionStore = sessionStore
        self.session = session
    }

    var currentUser: AuthenticatedUser? { currentSession?.user }

    func restoreSession() async {
        guard let persisted = try? sessionStore.load() else {
            state = .loggedOut
            return
        }

        do {
            let restored: StoredAuthSession
            if persisted.expiresAt <= Date().addingTimeInterval(60) {
                restored = try await refreshSession(using: persisted.refreshToken, previous: persisted)
            } else {
                restored = persisted
            }
            try sessionStore.save(restored)
            currentSession = restored
            state = .loggedIn
            await loadProfileIfPossible()
        } catch {
            currentSession = nil
            profile = nil
            try? sessionStore.clear()
            state = .loggedOut
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let response: AuthResponse
        do {
            response = try await request(
                path: "/auth/v1/signup",
                method: "POST",
                body: SignUpBody(
                    email: email,
                    password: password,
                    data: [
                        "display_name": displayName,
                        "preferred_locale": Locale.current.language.languageCode?.identifier ?? "en"
                    ]
                )
            )
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw map(error)
        }

        try await establishSession(from: response)
    }

    func signIn(email: String, password: String) async throws {
        let response: AuthResponse
        do {
            response = try await request(
                path: "/auth/v1/token?grant_type=password",
                method: "POST",
                body: PasswordBody(email: email, password: password)
            )
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw map(error)
        }

        try await establishSession(from: response)
    }

    func signOut() async {
        if let currentSession {
            _ = try? await requestNoContent(
                path: "/auth/v1/logout",
                method: "POST",
                body: EmptyBody(),
                bearerToken: currentSession.accessToken
            )
        }
        self.currentSession = nil
        profile = nil
        isPasswordRecoveryActive = false
        try? sessionStore.clear()
        state = .loggedOut
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await requestNoContent(
            path: "/auth/v1/recover",
            method: "POST",
            body: RecoverBody(
                email: email,
                redirectTo: Self.passwordResetRedirectURL
            )
        )
    }

    func refreshSession() async throws {
        guard let currentSession else { throw AuthenticationError.sessionUnavailable }
        let refreshed = try await refreshSession(using: currentSession.refreshToken, previous: currentSession)
        try sessionStore.save(refreshed)
        self.currentSession = refreshed
        state = .loggedIn
    }

    func fetchProfile() async throws -> UserProfile {
        guard let currentSession else { throw AuthenticationError.sessionUnavailable }
        let profiles: [UserProfile] = try await request(
            path: "/rest/v1/profiles?id=eq.\(currentSession.user.id.uuidString)&select=id,display_name,preferred_locale,onboarding_completed,created_at,updated_at",
            method: "GET",
            bearerToken: currentSession.accessToken
        )
        guard let profile = profiles.first else { throw AuthenticationError.profileUnavailable }
        self.profile = profile
        return profile
    }

    func updateProfile(displayName: String, preferredLocale: String) async throws -> UserProfile {
        guard let currentSession else { throw AuthenticationError.sessionUnavailable }
        let profiles: [UserProfile] = try await request(
            path: "/rest/v1/profiles?id=eq.\(currentSession.user.id.uuidString)",
            method: "PATCH",
            body: ProfileUpdateBody(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                preferredLocale: preferredLocale
            ),
            bearerToken: currentSession.accessToken,
            extraHeaders: ["Prefer": "return=representation"]
        )
        guard let profile = profiles.first else { throw AuthenticationError.profileUnavailable }
        self.profile = profile
        return profile
    }

    func updatePassword(_ password: String) async throws {
        guard let currentSession else { throw AuthenticationError.sessionUnavailable }
        _ = try await requestNoContent(
            path: "/auth/v1/user",
            method: "PUT",
            body: PasswordUpdateBody(password: password),
            bearerToken: currentSession.accessToken
        )
    }

    func deleteAccount() async throws {
        guard let currentSession else { throw AuthenticationError.sessionUnavailable }
        do {
            _ = try await requestNoContent(
                path: "/rest/v1/rpc/delete_current_user",
                method: "POST",
                body: EmptyBody(),
                bearerToken: currentSession.accessToken
            )
        } catch {
            throw AuthenticationError.accountDeletionFailed
        }
        self.currentSession = nil
        profile = nil
        isPasswordRecoveryActive = false
        try? sessionStore.clear()
        state = .loggedOut
    }

    func finishPasswordRecovery() {
        isPasswordRecoveryActive = false
    }

    func handleAuthCallback(_ url: URL) async {
        let values = callbackValues(from: url)
        guard
            let accessToken = values["access_token"],
            let refreshToken = values["refresh_token"]
        else { return }

        do {
            let user: AuthUserPayload = try await request(
                path: "/auth/v1/user",
                method: "GET",
                bearerToken: accessToken
            )
            let session = StoredAuthSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(Int(values["expires_in"] ?? "3600") ?? 3600)),
                user: user.authenticatedUser
            )
            try sessionStore.save(session)
            currentSession = session
            state = .loggedIn
            isPasswordRecoveryActive = values["type"] == "recovery"
            await loadProfileIfPossible()
        } catch {
            state = .loggedOut
        }
    }

    private func establishSession(from response: AuthResponse) async throws {
        guard
            let accessToken = response.accessToken,
            let refreshToken = response.refreshToken,
            let user = response.user
        else {
            throw AuthenticationError.sessionUnavailable
        }

        let session = StoredAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: response.expirationDate,
            user: user.authenticatedUser
        )
        try sessionStore.save(session)
        currentSession = session
        state = .loggedIn
        do {
            _ = try await fetchProfile()
        } catch {
            currentSession = nil
            profile = nil
            try? sessionStore.clear()
            state = .loggedOut
            throw AuthenticationError.profileUnavailable
        }
    }

    private func loadProfileIfPossible() async {
        _ = try? await fetchProfile()
    }

    private func refreshSession(using refreshToken: String, previous: StoredAuthSession) async throws -> StoredAuthSession {
        let response: AuthResponse = try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: RefreshBody(refreshToken: refreshToken)
        )
        guard
            let accessToken = response.accessToken,
            let newRefreshToken = response.refreshToken ?? Optional(refreshToken)
        else { throw AuthenticationError.sessionUnavailable }

        return StoredAuthSession(
            accessToken: accessToken,
            refreshToken: newRefreshToken,
            expiresAt: response.expirationDate,
            user: response.user?.authenticatedUser ?? previous.user
        )
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body? = nil,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        guard let request = try makeRequest(
            path: path,
            method: method,
            body: body,
            bearerToken: bearerToken,
            extraHeaders: extraHeaders
        ) else { throw AuthenticationError.invalidConfiguration }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationError.network
        }
        try validate(response: response, data: data)
        do {
            return try JSONDecoder.supabase.decode(T.self, from: data)
        } catch {
            throw AuthenticationError.unknown
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        try await request(
            path: path,
            method: method,
            body: Optional<EmptyBody>.none,
            bearerToken: bearerToken,
            extraHeaders: extraHeaders
        )
    }

    private func requestNoContent<Body: Encodable>(
        path: String,
        method: String,
        body: Body? = nil,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let request = try makeRequest(
            path: path,
            method: method,
            body: body,
            bearerToken: bearerToken,
            extraHeaders: extraHeaders
        ) else { throw AuthenticationError.invalidConfiguration }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationError.network
        }
        try validate(response: response, data: data)
        return data
    }

    private func requestNoContent(
        path: String,
        method: String,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        try await requestNoContent(
            path: path,
            method: method,
            body: Optional<EmptyBody>.none,
            bearerToken: bearerToken,
            extraHeaders: extraHeaders
        )
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        bearerToken: String?,
        extraHeaders: [String: String]
    ) throws -> URLRequest? {
        guard let configuration else { return nil }
        guard let url = URL(string: path, relativeTo: configuration.projectURL)?.absoluteURL else {
            throw AuthenticationError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.supabase.encode(body)
        }
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.network
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw map(status: httpResponse.statusCode, data: data)
        }
    }

    private func map(_ error: Error) -> AuthenticationError {
        if let error = error as? AuthenticationError { return error }
        return .network
    }

    private func map(status: Int, data: Data) -> AuthenticationError {
        let message = (try? JSONDecoder().decode(AuthErrorPayload.self, from: data))?.messageText?.lowercased() ?? ""
        if status == 429 { return .rateLimited }
        if status == 401 || message.contains("invalid login credentials") || message.contains("invalid_credentials") {
            return .invalidCredentials
        }
        if message.contains("already registered") || message.contains("user already exists") {
            return .emailAlreadyRegistered
        }
        if message.contains("password") && (message.contains("weak") || message.contains("at least") || message.contains("characters")) {
            return .weakPassword
        }
        return .unknown
    }

    private func callbackValues(from url: URL) -> [String: String] {
        let queryValues = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragmentValues = URLComponents(string: "https://callback.local/?\(url.fragment ?? "")")?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: (queryValues + fragmentValues).compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}

private struct SignUpBody: Encodable {
    let email: String
    let password: String
    let data: [String: String]
}

private struct PasswordBody: Encodable {
    let email: String
    let password: String
}

private struct RefreshBody: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

private struct RecoverBody: Encodable {
    let email: String
    let redirectTo: String

    enum CodingKeys: String, CodingKey {
        case email
        case redirectTo = "redirect_to"
    }
}

private struct PasswordUpdateBody: Encodable {
    let password: String
}

private struct ProfileUpdateBody: Encodable {
    let displayName: String
    let preferredLocale: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case preferredLocale = "preferred_locale"
    }
}

private struct EmptyBody: Encodable {}

private struct AuthErrorPayload: Decodable {
    let message: String?
    let msg: String?

    var messageText: String? { message ?? msg }
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let expiresAt: TimeInterval?
    let user: AuthUserPayload?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }

    var expirationDate: Date {
        if let expiresAt {
            return Date(timeIntervalSince1970: expiresAt)
        }
        return Date().addingTimeInterval(TimeInterval(expiresIn ?? 3600))
    }
}

private struct AuthUserPayload: Decodable {
    let id: UUID
    let email: String?

    var authenticatedUser: AuthenticatedUser {
        AuthenticatedUser(id: id, email: email ?? "")
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
