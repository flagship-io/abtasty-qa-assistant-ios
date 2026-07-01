//
//  QAssistantServiceTests.swift
//  ABTastyQAssistant_Tests
//
//  Unit + integration tests for the bucketing service:
//  URL building, validation, error mapping, and the full
//  download -> decode -> validate flow over a mocked network.
//

import XCTest
@testable import ABTastyQAssistant

// MARK: - Mock URLProtocol

/// Intercepts every request on its session and replies with a canned response.
final class MockURLProtocol: URLProtocol {
    /// (statusCode, body). Set before each request.
    static var stub: (status: Int, body: Data)?
    /// Force a transport-level error (e.g. NSURLErrorNotConnectedToInternet).
    static var error: Error?

    static func reset() { stub = nil; error = nil }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        if let error = MockURLProtocol.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let stub = MockURLProtocol.stub ?? (200, Data())
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: stub.status,
                                       httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class QAssistantServiceTests: XCTestCase {

    private var service: QAssistantService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        service = QAssistantService(envId: "env_123", apiKey: "key", enableLogging: false, session: session)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        service = nil
        super.tearDown()
    }

    private static let bucketingBody = Data("""
    {
      "campaigns": [
        {
          "id": "camp_1",
          "variationGroups": [
            { "id": "vg_1", "variations": [ { "id": "v_ref", "reference": true } ] }
          ]
        }
      ]
    }
    """.utf8)

    // MARK: - CDN URL

    func testCDNURLIsBuiltFromEnvId() {
        XCTAssertEqual(service.cdnURL?.absoluteString,
                       "https://cdn.flagship.io/env_123/bucketing.json")
    }

    // MARK: - Validation

    func testValidateEmptyJSONFails() {
        XCTAssertFalse(service.validateBucketingJSONStructure([:]))
        XCTAssertTrue(service.validateBucketingJSONStructure(["a": 1]))
    }

    func testValidateResponseRejectsNoCampaigns() {
        let empty = BucketingResponse(campaigns: [])
        XCTAssertFalse(service.validateBucketingResponse(empty))
    }

    func testValidateResponseRejectsEmptyCampaignID() throws {
        let json = """
        { "campaigns": [ { "name": "missing id" } ] }
        """
        let response = try JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
        XCTAssertFalse(service.validateBucketingResponse(response))   // id == ""
    }

    func testValidateResponseAcceptsValidCampaign() throws {
        let response = try JSONDecoder().decode(BucketingResponse.self, from: Self.bucketingBody)
        XCTAssertTrue(service.validateBucketingResponse(response))
    }

    // MARK: - Error descriptions

    func testErrorDescriptions() {
        XCTAssertEqual(QAServiceError.invalidURL.errorDescription, "Invalid CDN URL")
        XCTAssertEqual(QAServiceError.httpError(statusCode: 404).errorDescription,
                       "HTTP error with status code: 404")
        XCTAssertNotNil(QAServiceError.timeout.errorDescription)
        XCTAssertNotNil(QAServiceError.invalidJSON.errorDescription)
    }

    // MARK: - Integration: download -> decode -> validate

    func testDownloadBucketingConfigSuccess() {
        MockURLProtocol.stub = (200, Self.bucketingBody)

        let exp = expectation(description: "config downloaded")
        service.downloadBucketingConfig { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.campaigns.count, 1)
                XCTAssertEqual(response.campaigns.first?.id, "camp_1")
                XCTAssertTrue(self.service.validateBucketingResponse(response))
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testDownloadBucketingJSONSuccess() {
        MockURLProtocol.stub = (200, Self.bucketingBody)

        let exp = expectation(description: "json downloaded")
        service.downloadBucketingJSON { result in
            if case .success(let json) = result {
                XCTAssertNotNil(json["campaigns"])
            } else {
                XCTFail("Expected success")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testHTTPErrorStatusIsMapped() {
        MockURLProtocol.stub = (500, Data("{}".utf8))

        let exp = expectation(description: "http error")
        service.downloadBucketingJSON { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure"); exp.fulfill(); return
            }
            XCTAssertEqual(error as? QAServiceError, .httpError(statusCode: 500))
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testInvalidJSONIsMapped() {
        // Valid JSON, but a top-level array instead of an object -> cast fails -> .invalidJSON.
        MockURLProtocol.stub = (200, Data("[1, 2, 3]".utf8))

        let exp = expectation(description: "invalid json")
        service.downloadBucketingJSON { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure"); exp.fulfill(); return
            }
            XCTAssertEqual(error as? QAServiceError, .invalidJSON)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testNoInternetErrorIsMapped() {
        MockURLProtocol.error = NSError(domain: NSURLErrorDomain,
                                        code: NSURLErrorNotConnectedToInternet)

        let exp = expectation(description: "no internet")
        service.downloadBucketingJSON { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure"); exp.fulfill(); return
            }
            XCTAssertEqual(error as? QAServiceError, .noInternetConnection)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testDownloadConfigPropagatesNetworkFailure() {
        MockURLProtocol.error = NSError(domain: NSURLErrorDomain,
                                        code: NSURLErrorNotConnectedToInternet)

        let exp = expectation(description: "config failure")
        service.downloadBucketingConfig { result in
            if case .failure = result {} else { XCTFail("Expected failure") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}

// Allow XCTAssertEqual on the error enum.
extension QAServiceError: Equatable {
    public static func == (lhs: QAServiceError, rhs: QAServiceError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
