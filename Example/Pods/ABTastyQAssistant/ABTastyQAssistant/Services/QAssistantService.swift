//
//  QAssistantService.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 22/04/2026.
//

import Foundation

private let cdnBaseURL = "https://cdn.flagship.io/%@/bucketing.json"

class QAssistantService: NSObject {

    let envId: String
    let apiKey: String
    var enableLogging: Bool

    private let session: URLSession

    init(envId: String, apiKey: String, enableLogging: Bool = true, session: URLSession? = nil) {
        self.envId         = envId
        self.apiKey        = apiKey
        self.enableLogging = enableLogging
        self.session       = session ?? URLSession(configuration: .default)
    }

    // MARK: - CDN URL

    var cdnURL: URL? {
        let urlString = String(format: cdnBaseURL, envId)
        log("CDN URL: \(urlString)")
        return URL(string: urlString)
    }

    // MARK: - Download raw JSON (completion)

    func downloadBucketingJSON(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = cdnURL else {
            completion(.failure(QAServiceError.invalidURL))
            return
        }
        log("Downloading bucketing JSON from: \(url)")

        let request = makeRequest(url: url)
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorNotConnectedToInternet {
                    self.log("No internet connection")
                    completion(.failure(QAServiceError.noInternetConnection))
                } else if nsError.code == NSURLErrorTimedOut {
                    self.log("Request timed out")
                    completion(.failure(QAServiceError.timeout))
                } else {
                    self.log("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }

            do {
                let json = try self.parseJSON(data: data, response: response)
                self.log("Successfully downloaded and parsed bucketing JSON")
                completion(.success(json))
            } catch {
                self.log("Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Download raw JSON with timeout (completion)

    func downloadBucketingJSONWithTimeout(_ timeout: TimeInterval = 30,
                                          completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = cdnURL else {
            completion(.failure(QAServiceError.invalidURL))
            return
        }
        log("Downloading bucketing JSON with timeout \(timeout)s from: \(url)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = timeout
        config.timeoutIntervalForResource = timeout
        let timeoutSession = URLSession(configuration: config)

        let request = makeRequest(url: url)
        timeoutSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    self.log("Request timed out")
                    completion(.failure(QAServiceError.timeout))
                } else if nsError.code == NSURLErrorNotConnectedToInternet {
                    self.log("No internet connection")
                    completion(.failure(QAServiceError.noInternetConnection))
                } else {
                    self.log("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }

            do {
                let json = try self.parseJSON(data: data, response: response)
                self.log("Successfully downloaded bucketing JSON (with timeout)")
                completion(.success(json))
            } catch {
                self.log("Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Download typed BucketingResponse (completion)

    func downloadBucketingConfig(completion: @escaping (Result<BucketingResponse, Error>) -> Void) {
        downloadBucketingJSON { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                self.decodeResponse(from: json, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func downloadBucketingConfigWithTimeout(_ timeout: TimeInterval = 30,
                                            completion: @escaping (Result<BucketingResponse, Error>) -> Void) {
        downloadBucketingJSONWithTimeout(timeout) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                self.decodeResponse(from: json, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Async/Await (iOS 15+)

    @available(iOS 15.0, *)
    func downloadBucketingJSON() async throws -> [String: Any] {
        guard let url = cdnURL else { throw QAServiceError.invalidURL }
        log("Downloading bucketing JSON (async) from: \(url)")
        let (data, response) = try await URLSession.shared.data(for: makeRequest(url: url))
        let json = try parseJSON(data: data, response: response)
        log("Successfully downloaded bucketing JSON (async)")
        return json
    }

    @available(iOS 15.0, *)
    func downloadBucketingConfig() async throws -> BucketingResponse {
        let json = try await downloadBucketingJSON()
        log("Parsing JSON into BucketingResponse (async)")
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(BucketingResponse.self, from: data)
        log("Successfully parsed BucketingResponse with \(response.campaigns.count) campaigns (async)")
        return response
    }

    // MARK: - Validation

    func validateBucketingJSONStructure(_ json: [String: Any]) -> Bool {
        guard !json.isEmpty else {
            log("Validation failed: empty JSON")
            return false
        }
        return true
    }

    func validateBucketingResponse(_ response: BucketingResponse) -> Bool {
        log("Validating BucketingResponse structure")

        guard !response.campaigns.isEmpty else {
            log("Validation failed: no campaigns found")
            return false
        }

        for campaign in response.campaigns {
            guard !campaign.id.isEmpty else {
                log("Validation failed: campaign with empty ID found")
                return false
            }
            if campaign.variationGroups.isEmpty {
                log("Validation warning: campaign \(campaign.id) has no variation groups")
            }
        }

        log("BucketingResponse validation successful")
        return true
    }

    // MARK: - Private helpers

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func parseJSON(data: Data?, response: URLResponse?) throws -> [String: Any] {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QAServiceError.invalidResponse
        }
        log("Response status: \(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            log("Failed to download JSON. Status: \(httpResponse.statusCode)")
            throw QAServiceError.httpError(statusCode: httpResponse.statusCode)
        }
        guard let data else {
            throw QAServiceError.noData
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QAServiceError.invalidJSON
        }
        return json
    }

    private func decodeResponse(from json: [String: Any],
                                 completion: @escaping (Result<BucketingResponse, Error>) -> Void) {
        do {
            let data     = try JSONSerialization.data(withJSONObject: json)
            let response = try JSONDecoder().decode(BucketingResponse.self, from: data)
            log("Successfully parsed BucketingResponse with \(response.campaigns.count) campaigns")
            completion(.success(response))
        } catch {
            log("Failed to parse BucketingResponse: \(error)")
            completion(.failure(error))
        }
    }

    private func log(_ message: String) {
        guard enableLogging else { return }
        print("[QAssistantService] \(message)")
    }
}

// MARK: - Errors

enum QAServiceError: LocalizedError {
    case invalidURL
    case noInternetConnection
    case timeout
    case invalidResponse
    case httpError(statusCode: Int)
    case noData
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid CDN URL"
        case .noInternetConnection:  return "No internet connection. Please check your network settings."
        case .timeout:               return "Request timed out. Please try again."
        case .invalidResponse:       return "Invalid response from server"
        case .httpError(let code):   return "HTTP error with status code: \(code)"
        case .noData:                return "No data received"
        case .invalidJSON:           return "Invalid JSON format received from CDN"
        }
    }
}
