import Foundation
import XCTest
@testable import Initium

@MainActor
final class AuthenticationServiceTests: XCTestCase {
    private let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    override func tearDown() {
        super.tearDown()
        MockAuthURLProtocol.handler = nil
        MockAuthURLProtocol.lastBody = nil
    }

    func testSignupCreatesImmediateSessionAndFetchesProfile() async throws {
        let store = InMemoryAuthSessionStore()
        let service = makeService(store: store) { request in
            if request.path.hasSuffix("/auth/v1/signup") {
                return .json(200, """
                {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"11111111-1111-1111-1111-111111111111","email":"test@example.com"}}
                """)
            }
            return .json(200, self.profileJSON(email: "test@example.com"))
        }

        try await service.signUp(email: "test@example.com", password: "strong-pass", displayName: "Test")

        XCTAssertEqual(service.state, AuthenticationState.loggedIn)
        XCTAssertEqual(service.currentUser?.email, "test@example.com")
        XCTAssertEqual(service.profile?.displayName, "Test")
        XCTAssertNotNil(try store.load())
    }

    func testSignupExistingEmailMapsToFriendlyError() async {
        let service = makeService { _ in
            .json(422, "{\"msg\":\"User already registered\"}")
        }

        do {
            try await service.signUp(email: "test@example.com", password: "strong-pass", displayName: "Test")
            XCTFail("Expected existing email error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .emailAlreadyRegistered)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoginInvalidCredentialsMapsToFriendlyError() async {
        let service = makeService { _ in
            .json(400, "{\"msg\":\"Invalid login credentials\"}")
        }

        do {
            try await service.signIn(email: "test@example.com", password: "wrong")
            XCTFail("Expected invalid credentials error")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLogoutClearsPersistedSessionAndKeepsLocalStateIndependent() async throws {
        let store = InMemoryAuthSessionStore()
        let service = makeService(store: store) { request in
            if request.path.hasSuffix("/auth/v1/signup") {
                return .json(200, """
                {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"11111111-1111-1111-1111-111111111111","email":"test@example.com"}}
                """)
            }
            if request.path.hasSuffix("/auth/v1/logout") { return .json(204, "") }
            return .json(200, self.profileJSON(email: "test@example.com"))
        }
        try await service.signUp(email: "test@example.com", password: "strong-pass", displayName: "Test")

        await service.signOut()

        XCTAssertEqual(service.state, AuthenticationState.loggedOut)
        XCTAssertNil(service.currentUser)
        XCTAssertNil(try store.load())
    }

    func testSessionRestoreUsesPersistedSession() async throws {
        let store = InMemoryAuthSessionStore()
        try store.save(StoredAuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            user: AuthenticatedUser(id: userID, email: "test@example.com")
        ))
        let service = makeService(store: store) { _ in
            .json(200, self.profileJSON(email: "test@example.com"))
        }

        await service.restoreSession()

        XCTAssertEqual(service.state, AuthenticationState.loggedIn)
        XCTAssertEqual(service.profile?.id, userID)
    }

    func testExpiredSessionRefreshesBeforeEnteringMainState() async throws {
        let store = InMemoryAuthSessionStore()
        try store.save(StoredAuthSession(
            accessToken: "expired",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-60),
            user: AuthenticatedUser(id: userID, email: "test@example.com")
        ))
        let service = makeService(store: store) { request in
            if request.path.contains("grant_type=refresh_token") {
                return .json(200, """
                {"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}
                """)
            }
                return .json(200, self.profileJSON(email: "test@example.com"))
        }

        await service.restoreSession()

        XCTAssertEqual(service.state, AuthenticationState.loggedIn)
        XCTAssertEqual(try store.load()?.accessToken, "new-access")
    }

    func testResetPasswordUsesConfiguredDeepLink() async throws {
        let service = makeService { _ in
            return .json(204, "")
        }

        try await service.sendPasswordReset(email: "test@example.com")

        XCTAssertEqual(AuthenticationService.passwordResetRedirectURL, "initium://auth/callback")
    }

    func testProfileUpdateReturnsUpdatedProfile() async throws {
        let service = makeService { request in
            if request.path.hasSuffix("/auth/v1/signup") {
                return .json(200, """
                {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"11111111-1111-1111-1111-111111111111","email":"test@example.com"}}
                """)
            }
            if request.httpMethod == "PATCH" {
                return .json(200, self.profileJSON(email: "test@example.com", displayName: "Updated"))
            }
            return .json(200, self.profileJSON(email: "test@example.com"))
        }
        try await service.signUp(email: "test@example.com", password: "strong-pass", displayName: "Test")

        let profile = try await service.updateProfile(displayName: "Updated", preferredLocale: "en")

        XCTAssertEqual(profile.displayName, "Updated")
        XCTAssertEqual(service.profile?.displayName, "Updated")
    }

    func testDeleteAccountCallsSecureRpcAndClearsSession() async throws {
        let store = InMemoryAuthSessionStore()
        let service = makeService(store: store) { request in
            if request.path.hasSuffix("/auth/v1/signup") {
                return .json(200, """
                {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"11111111-1111-1111-1111-111111111111","email":"test@example.com"}}
                """)
            }
            if request.path.hasSuffix("/rest/v1/rpc/delete_current_user") { return .json(204, "") }
            return .json(200, self.profileJSON(email: "test@example.com"))
        }
        try await service.signUp(email: "test@example.com", password: "strong-pass", displayName: "Test")

        try await service.deleteAccount()

        XCTAssertEqual(service.state, AuthenticationState.loggedOut)
        XCTAssertNil(try store.load())
    }

    private func makeService(
        store: InMemoryAuthSessionStore = InMemoryAuthSessionStore(),
        handler: @escaping (URLRequest) -> MockAuthResponse
    ) -> AuthenticationService {
        MockAuthURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAuthURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return AuthenticationService(
            configuration: SupabaseConfiguration(
                projectURL: URL(string: "https://ffgqokjkxqloepyevbct.supabase.co")!,
                anonKey: "test-public-key"
            ),
            sessionStore: store,
            session: session
        )
    }

    private func profileJSON(
        email: String,
        displayName: String = "Test"
    ) -> String {
        """
        [{"id":"\(userID.uuidString)","display_name":"\(displayName)","preferred_locale":"fr","onboarding_completed":false,"created_at":"2026-10-07T00:00:00Z","updated_at":"2026-10-07T00:00:00Z"}]
        """
    }
}

private final class InMemoryAuthSessionStore: AuthSessionStoring {
    private var session: StoredAuthSession?

    func load() throws -> StoredAuthSession? { session }
    func save(_ session: StoredAuthSession) throws { self.session = session }
    func clear() throws { session = nil }
}

private struct MockAuthResponse {
    let response: HTTPURLResponse
    let data: Data

    static func json(_ status: Int, _ body: String) -> Self {
        Self(
            response: HTTPURLResponse(
                url: URL(string: "https://ffgqokjkxqloepyevbct.supabase.co")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            data: Data(body.utf8)
        )
    }
}

private final class MockAuthURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> MockAuthResponse)?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        if let httpBody = request.httpBody {
            Self.lastBody = httpBody
        } else if let bodyStream = request.httpBodyStream {
            bodyStream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while bodyStream.hasBytesAvailable {
                let count = bodyStream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            bodyStream.close()
            Self.lastBody = data
        }
        let result = handler(request)
        client?.urlProtocol(self, didReceive: result.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}

private extension URLRequest {
    var path: String { url?.absoluteString ?? "" }
}
