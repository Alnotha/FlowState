//
//  AuthModels.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import Foundation

// MARK: - Auth State

nonisolated enum AuthState: Equatable, Sendable {
    case signedOut
    case signingIn
    case signedIn(userID: String)
    case error(String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

// MARK: - Auth API Types

nonisolated struct AppleAuthRequest: Codable, Sendable {
    let identityToken: String
    let userIdentifier: String
    let nonce: String?
    let nonceSignature: String?
    let nonceExpiresAt: Int?
}

nonisolated struct NonceData: Sendable {
    let nonce: String
    let signature: String
    let expiresAt: Int
}

nonisolated struct AuthTokenResponse: Codable, Sendable {
    let token: String
    let expiresIn: Int
    let userID: String
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noIdentityToken
    case appleSignInFailed(String)
    case serverValidationFailed(String)
    case tokenExpired
    case noToken
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noIdentityToken: return "Could not retrieve identity token from Apple."
        case .appleSignInFailed(let msg): return "Sign in failed: \(msg)"
        case .serverValidationFailed(let msg): return "Verification failed: \(msg)"
        case .tokenExpired: return "Your session has expired. Please sign in again."
        case .noToken: return "Not signed in."
        case .networkError(let err): return err.localizedDescription
        }
    }
}
