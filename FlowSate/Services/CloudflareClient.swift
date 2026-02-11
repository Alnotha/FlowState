//
//  CloudflareClient.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import Foundation

actor CloudflareClient {
    static let shared = CloudflareClient()

    private let session: URLSession
    private let appBundle = "alnotha.FlowSate"
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 30

    // MARK: - Worker URL

    static var workerURL: String {
        get { UserDefaults.standard.string(forKey: "aiWorkerURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "aiWorkerURL") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Send Message

    func sendMessage(
        system: String,
        messages: [ClaudeMessage],
        model: ClaudeModel = .haiku,
        maxTokens: Int = 1024,
        temperature: Double = 0.7
    ) async throws -> ClaudeResponse {
        try checkRateLimit()

        let url = try workerEndpoint()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appBundle, forHTTPHeaderField: "X-App-Bundle")
        if let token = authorizationToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw ClaudeAPIError.unauthorized
        }

        let body = ClaudeRequestBody(
            model: model.identifier,
            max_tokens: maxTokens,
            system: system,
            messages: messages.map { ["role": $0.role, "content": $0.content] },
            temperature: temperature,
            stream: false
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse(statusCode: 0)
        }

        switch httpResponse.statusCode {
        case 200:
            let apiResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
            if let error = apiResponse.error {
                throw ClaudeAPIError.apiError(error.message ?? "Unknown API error")
            }
            guard let text = apiResponse.content?.first?.text else {
                throw ClaudeAPIError.decodingError
            }
            return ClaudeResponse(
                content: text,
                inputTokens: apiResponse.usage?.input_tokens ?? 0,
                outputTokens: apiResponse.usage?.output_tokens ?? 0
            )
        case 401:
            let refreshed = await AuthenticationManager.shared.refreshTokenIfNeeded()
            if !refreshed {
                await AuthenticationManager.shared.signOut()
            }
            throw ClaudeAPIError.unauthorized
        case 429:
            throw ClaudeAPIError.rateLimited
        case 529:
            throw ClaudeAPIError.overloaded
        default:
            throw ClaudeAPIError.invalidResponse(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Stream Message

    func streamMessage(
        system: String,
        messages: [ClaudeMessage],
        model: ClaudeModel = .sonnet,
        maxTokens: Int = 1024,
        temperature: Double = 0.7
    ) throws -> AsyncThrowingStream<String, Error> {
        try checkRateLimit()
        let url = try workerEndpoint()

        let session = self.session
        let appBundle = self.appBundle
        let token = authorizationToken()

        let body = ClaudeRequestBody(
            model: model.identifier,
            max_tokens: maxTokens,
            system: system,
            messages: messages.map { ["role": $0.role, "content": $0.content] },
            temperature: temperature,
            stream: true
        )

        let bodyData = try JSONEncoder().encode(body)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(appBundle, forHTTPHeaderField: "X-App-Bundle")
                    if let token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    } else {
                        throw ClaudeAPIError.unauthorized
                    }
                    request.httpBody = bodyData

                    let (bytes, response) = try await session.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 401 {
                            let refreshed = await AuthenticationManager.shared.refreshTokenIfNeeded()
                            if !refreshed {
                                await AuthenticationManager.shared.signOut()
                            }
                            throw ClaudeAPIError.unauthorized
                        }
                        if httpResponse.statusCode == 429 {
                            throw ClaudeAPIError.rateLimited
                        }
                    }
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw ClaudeAPIError.invalidResponse(
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
                        )
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" { break }

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {
                                if event.type == "content_block_delta",
                                   let text = event.delta?.text {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Auth

    private func authorizationToken() -> String? {
        guard let expirationString = KeychainManager.loadString(key: .jwtExpiration),
              let expirationTimestamp = Double(expirationString),
              Date().timeIntervalSince1970 < (expirationTimestamp - 60) else {
            return nil
        }
        return KeychainManager.loadString(key: .jwt)
    }

    // MARK: - Helpers

    private func workerEndpoint() throws -> URL {
        let urlString = Self.workerURL
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw ClaudeAPIError.noWorkerURL
        }
        return url
    }

    private func checkRateLimit() throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < windowStart }
        guard requestTimestamps.count < maxRequestsPerMinute else {
            throw ClaudeAPIError.rateLimited
        }
        requestTimestamps.append(now)
    }
}

// MARK: - Stream Event Parsing

private nonisolated struct StreamEvent: Codable, Sendable {
    let type: String
    let delta: Delta?

    nonisolated struct Delta: Codable, Sendable {
        let type: String?
        let text: String?
    }
}
