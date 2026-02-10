//
//  AuthenticationManager.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import Foundation
import Combine
import AuthenticationServices
import SwiftUI

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published private(set) var authState: AuthState = .signedOut
    @Published private(set) var userDisplayName: String?

    private init() {
        userDisplayName = UserDefaults.standard.string(forKey: "authUserDisplayName")
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        guard let jwt = KeychainManager.loadString(key: .jwt),
              let userID = KeychainManager.loadString(key: .appleUserID) else {
            authState = .signedOut
            return
        }

        if isTokenExpired() {
            authState = .signedOut
            KeychainManager.deleteAll()
            return
        }

        // Verify Apple ID credential is still valid
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            Task { @MainActor in
                switch state {
                case .authorized:
                    self?.authState = .signedIn(userID: userID)
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    self?.authState = .signedIn(userID: userID)
                }
            }
        }
    }

    // MARK: - Sign In

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async {
        authState = .signingIn

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            authState = .error(AuthError.noIdentityToken.localizedDescription ?? "Unknown error")
            return
        }

        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        let request = AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authCode,
            userIdentifier: credential.user,
            email: credential.email,
            fullName: fullName.isEmpty ? nil : fullName
        )

        do {
            let tokenResponse = try await exchangeTokenWithWorker(request)

            KeychainManager.saveString(key: .jwt, value: tokenResponse.token)
            KeychainManager.saveString(key: .appleUserID, value: credential.user)

            let expiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            KeychainManager.saveString(key: .jwtExpiration, value: String(expiration.timeIntervalSince1970))

            // Store display name if first sign-in (Apple only provides it once)
            if !fullName.isEmpty {
                UserDefaults.standard.set(fullName, forKey: "authUserDisplayName")
            }
            userDisplayName = UserDefaults.standard.string(forKey: "authUserDisplayName")

            authState = .signedIn(userID: credential.user)
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    // MARK: - Token Exchange

    private func exchangeTokenWithWorker(_ request: AppleAuthRequest) async throws -> AuthTokenResponse {
        let workerURL = CloudflareClient.workerURL
        guard !workerURL.isEmpty else {
            throw AuthError.serverValidationFailed("Worker URL not configured")
        }

        let urlString = workerURL.hasSuffix("/") ? workerURL + "auth/apple" : workerURL + "/auth/apple"
        guard let url = URL(string: urlString) else {
            throw AuthError.serverValidationFailed("Invalid worker URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("alnotha.FlowSate", forHTTPHeaderField: "X-App-Bundle")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.serverValidationFailed("Status \(httpResponse.statusCode): \(body)")
        }

        return try JSONDecoder().decode(AuthTokenResponse.self, from: data)
    }

    // MARK: - Token Access

    var currentToken: String? {
        guard authState.isSignedIn else { return nil }
        guard !isTokenExpired() else {
            Task { @MainActor in signOut() }
            return nil
        }
        return KeychainManager.loadString(key: .jwt)
    }

    private func isTokenExpired() -> Bool {
        guard let expirationString = KeychainManager.loadString(key: .jwtExpiration),
              let expirationTimestamp = Double(expirationString) else {
            return true
        }
        return Date().timeIntervalSince1970 >= (expirationTimestamp - 60)
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async -> Bool {
        guard let jwt = KeychainManager.loadString(key: .jwt) else { return false }

        guard let expirationString = KeychainManager.loadString(key: .jwtExpiration),
              let expirationTimestamp = Double(expirationString) else { return false }

        let timeUntilExpiry = expirationTimestamp - Date().timeIntervalSince1970
        guard timeUntilExpiry < 300 && timeUntilExpiry > 0 else {
            return timeUntilExpiry > 0
        }

        do {
            let workerURL = CloudflareClient.workerURL
            let urlString = workerURL.hasSuffix("/") ? workerURL + "auth/refresh" : workerURL + "/auth/refresh"
            guard let url = URL(string: urlString) else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("alnotha.FlowSate", forHTTPHeaderField: "X-App-Bundle")
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(AuthRefreshRequest(token: jwt))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }

            let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
            KeychainManager.saveString(key: .jwt, value: tokenResponse.token)
            let expiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            KeychainManager.saveString(key: .jwtExpiration, value: String(expiration.timeIntervalSince1970))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainManager.deleteAll()
        UserDefaults.standard.removeObject(forKey: "authUserDisplayName")
        userDisplayName = nil
        authState = .signedOut
    }
}
