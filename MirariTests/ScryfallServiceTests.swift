import XCTest
@testable import Mirari

// MARK: - Mock URL Protocol

/// A mock URL protocol for testing network requests without hitting the real API
final class MockURLProtocol: URLProtocol {
    /// Handler to provide mock responses
    /// Using nonisolated(unsafe) because access is controlled by test framework (single-threaded test execution)
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("No request handler set")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Scryfall Service Tests

@MainActor
final class ScryfallServiceTests: XCTestCase {

    var service: ScryfallService!
    var mockSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        service = ScryfallService(session: mockSession)
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        service = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func mockResponse(
        json: String,
        statusCode: Int = 200,
        for urlContaining: String? = nil
    ) {
        MockURLProtocol.requestHandler = { request in
            if let urlContaining = urlContaining {
                XCTAssertTrue(
                    request.url?.absoluteString.contains(urlContaining) ?? false,
                    "Expected URL to contain '\(urlContaining)', got '\(request.url?.absoluteString ?? "nil")'"
                )
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json.data(using: .utf8)!)
        }
    }

    // MARK: - Lookup Card Tests

    func testLookupCard_success() async throws {
        let cardJSON = """
        {
            "id": "e3285e6b-3e79-4d7c-bf96-d920f973b122",
            "name": "Lightning Bolt",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/e3285e6b",
            "scryfall_uri": "https://scryfall.com/card/lea/161",
            "layout": "normal",
            "set_id": "288bd996-960e-448b-a187-9f12d6281c7d",
            "set": "lea",
            "set_name": "Limited Edition Alpha",
            "set_type": "core",
            "collector_number": "161",
            "rarity": "common",
            "mana_cost": "{R}",
            "type_line": "Instant",
            "oracle_text": "Lightning Bolt deals 3 damage to any target."
        }
        """

        mockResponse(json: cardJSON, for: "/cards/lea/161")

        let card = try await service.lookupCard(setCode: "lea", collectorNumber: "161")

        XCTAssertEqual(card.name, "Lightning Bolt")
        XCTAssertEqual(card.set, "lea")
        XCTAssertEqual(card.collectorNumber, "161")
        XCTAssertEqual(card.manaCost, "{R}")
    }

    func testLookupCard_normalizesSetCode() async throws {
        let cardJSON = """
        {
            "id": "abc123",
            "name": "Test Card",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/tst/1",
            "layout": "normal",
            "set_id": "set123",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common"
        }
        """

        mockResponse(json: cardJSON, for: "/cards/tst/1")

        // Use uppercase set code - should be normalized to lowercase
        let card = try await service.lookupCard(setCode: "TST", collectorNumber: "1")

        XCTAssertEqual(card.set, "tst")
    }

    func testLookupCard_notFound() async throws {
        let errorJSON = """
        {
            "object": "error",
            "code": "not_found",
            "status": 404,
            "details": "No card found with the given ID."
        }
        """

        mockResponse(json: errorJSON, statusCode: 404)

        do {
            _ = try await service.lookupCard(setCode: "xyz", collectorNumber: "999")
            XCTFail("Expected notFound error")
        } catch let error as ScryfallError {
            XCTAssertEqual(error, .notFound)
        }
    }

    func testLookupCard_rateLimited() async throws {
        let errorJSON = """
        {
            "object": "error",
            "code": "too_many_requests",
            "status": 429,
            "details": "You have exceeded the rate limit."
        }
        """

        mockResponse(json: errorJSON, statusCode: 429)

        do {
            _ = try await service.lookupCard(setCode: "lea", collectorNumber: "161")
            XCTFail("Expected rateLimited error")
        } catch let error as ScryfallError {
            XCTAssertEqual(error, .rateLimited)
        }
    }

    // MARK: - Search by Name Tests

    func testSearchByName_success() async throws {
        let cardJSON = """
        {
            "id": "abc123",
            "name": "Counterspell",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/lea/54",
            "layout": "normal",
            "set_id": "set123",
            "set": "lea",
            "set_name": "Limited Edition Alpha",
            "set_type": "core",
            "collector_number": "54",
            "rarity": "uncommon"
        }
        """

        mockResponse(json: cardJSON, for: "/cards/named?exact=")

        let card = try await service.searchByName("Counterspell")

        XCTAssertEqual(card.name, "Counterspell")
    }

    func testFuzzySearchByName_success() async throws {
        let cardJSON = """
        {
            "id": "abc123",
            "name": "Lightning Bolt",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/2xm/117",
            "layout": "normal",
            "set_id": "set123",
            "set": "2xm",
            "set_name": "Double Masters",
            "set_type": "masters",
            "collector_number": "117",
            "rarity": "uncommon"
        }
        """

        mockResponse(json: cardJSON, for: "/cards/named?fuzzy=")

        // Typo in name - fuzzy search should still work
        let card = try await service.fuzzySearchByName("Lightening Bolt")

        XCTAssertEqual(card.name, "Lightning Bolt")
    }

    // MARK: - Search Query Tests

    func testSearch_success() async throws {
        let searchJSON = """
        {
            "object": "list",
            "total_cards": 50,
            "has_more": true,
            "data": [
                {
                    "id": "card1",
                    "name": "Lightning Bolt",
                    "lang": "en",
                    "uri": "https://api.scryfall.com/cards/card1",
                    "scryfall_uri": "https://scryfall.com/card/2xm/117",
                    "layout": "normal",
                    "set_id": "set1",
                    "set": "2xm",
                    "set_name": "Double Masters",
                    "set_type": "masters",
                    "collector_number": "117",
                    "rarity": "uncommon"
                }
            ]
        }
        """

        mockResponse(json: searchJSON, for: "/cards/search")

        let response = try await service.search(query: "Lightning Bolt", page: 1)

        XCTAssertEqual(response.totalCards, 50)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].name, "Lightning Bolt")
    }

    // MARK: - Lookup From Detection Tests

    func testLookupFromDetection_exactLookup() async throws {
        let cardJSON = """
        {
            "id": "abc123",
            "name": "Lightning Bolt",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/lea/161",
            "layout": "normal",
            "set_id": "set123",
            "set": "lea",
            "set_name": "Limited Edition Alpha",
            "set_type": "core",
            "collector_number": "161",
            "rarity": "common"
        }
        """

        mockResponse(json: cardJSON, for: "/cards/lea/161")

        let detection = DetectionResult(
            name: "Lightning Bolt",
            setCode: "lea",
            setName: "Limited Edition Alpha",
            collectorNumber: "161",
            confidence: 0.95,
            features: []
        )

        let card = try await service.lookupFromDetection(detection)

        XCTAssertEqual(card.name, "Lightning Bolt")
        XCTAssertEqual(card.set, "lea")
    }

    func testLookupFromDetection_fallsBackToNameSearch() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1

            let url = request.url!.absoluteString

            // First request: exact lookup - return 404
            if url.contains("/cards/xxx/999") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let errorJSON = """
                {"object": "error", "code": "not_found", "status": 404, "details": "Not found"}
                """.data(using: .utf8)!
                return (response, errorJSON)
            }

            // Second request: name+set search - return 404
            if url.contains("/cards/search") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let errorJSON = """
                {"object": "error", "code": "not_found", "status": 404, "details": "Not found"}
                """.data(using: .utf8)!
                return (response, errorJSON)
            }

            // Third request: exact name - return card
            if url.contains("/cards/named?exact=") {
                let cardJSON = """
                {
                    "id": "abc123",
                    "name": "Lightning Bolt",
                    "lang": "en",
                    "uri": "https://api.scryfall.com/cards/abc123",
                    "scryfall_uri": "https://scryfall.com/card/2xm/117",
                    "layout": "normal",
                    "set_id": "set123",
                    "set": "2xm",
                    "set_name": "Double Masters",
                    "set_type": "masters",
                    "collector_number": "117",
                    "rarity": "uncommon"
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, cardJSON)
            }

            XCTFail("Unexpected request: \(url)")
            throw ScryfallError.notFound
        }

        let detection = DetectionResult(
            name: "Lightning Bolt",
            setCode: "xxx",  // Invalid set code
            setName: nil,
            collectorNumber: "999",
            confidence: 0.7,
            features: []
        )

        let card = try await service.lookupFromDetection(detection)

        XCTAssertEqual(card.name, "Lightning Bolt")
        // Should have made multiple requests (exact lookup failed, fell back to name search)
        XCTAssertGreaterThan(requestCount, 1)
    }

    func testLookupFromDetection_nameOnlyFallback() async throws {
        // Test when detection has no setCode or collectorNumber
        // Should skip exact lookup and name+set search, go directly to exact name search
        var requestedURLs: [String] = []
        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            requestedURLs.append(url)

            // Only exact name search should be called
            if url.contains("/cards/named?exact=") {
                let cardJSON = """
                {
                    "id": "abc123",
                    "name": "Counterspell",
                    "lang": "en",
                    "uri": "https://api.scryfall.com/cards/abc123",
                    "scryfall_uri": "https://scryfall.com/card/cmr/64",
                    "layout": "normal",
                    "set_id": "set123",
                    "set": "cmr",
                    "set_name": "Commander Legends",
                    "set_type": "draft_innovation",
                    "collector_number": "64",
                    "rarity": "uncommon"
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, cardJSON)
            }

            XCTFail("Unexpected request: \(url)")
            throw ScryfallError.notFound
        }

        let detection = DetectionResult(
            name: "Counterspell",
            setCode: nil,  // No set code
            setName: nil,
            collectorNumber: nil,  // No collector number
            confidence: 0.8,
            features: []
        )

        let card = try await service.lookupFromDetection(detection)

        XCTAssertEqual(card.name, "Counterspell")
        // Should only have made exact name request (no set code/number = skip first two strategies)
        XCTAssertEqual(requestedURLs.count, 1)
        XCTAssertTrue(requestedURLs[0].contains("/cards/named?exact="))
    }

    func testLookupFromDetection_fuzzyFallback() async throws {
        // Test when exact name search fails and falls back to fuzzy
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let url = request.url!.absoluteString

            // Exact name search - return 404
            if url.contains("/cards/named?exact=") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let errorJSON = """
                {"object": "error", "code": "not_found", "status": 404, "details": "Not found"}
                """.data(using: .utf8)!
                return (response, errorJSON)
            }

            // Fuzzy search - return card
            if url.contains("/cards/named?fuzzy=") {
                let cardJSON = """
                {
                    "id": "abc123",
                    "name": "Llanowar Elves",
                    "lang": "en",
                    "uri": "https://api.scryfall.com/cards/abc123",
                    "scryfall_uri": "https://scryfall.com/card/m19/314",
                    "layout": "normal",
                    "set_id": "set123",
                    "set": "m19",
                    "set_name": "Core Set 2019",
                    "set_type": "core",
                    "collector_number": "314",
                    "rarity": "common"
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, cardJSON)
            }

            XCTFail("Unexpected request: \(url)")
            throw ScryfallError.notFound
        }

        let detection = DetectionResult(
            name: "Llanowar Elfs",  // Misspelled
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.6,
            features: []
        )

        let card = try await service.lookupFromDetection(detection)

        XCTAssertEqual(card.name, "Llanowar Elves")  // Corrected by fuzzy search
        XCTAssertEqual(requestCount, 2)  // Exact failed, fuzzy succeeded
    }

    func testLookupCard_encodesSpecialCollectorNumbers() async throws {
        // Test that special collector numbers like "123a" or "★123" are properly URL encoded
        let cardJSON = """
        {
            "id": "abc123",
            "name": "Plains",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/jmp/38",
            "layout": "normal",
            "set_id": "set123",
            "set": "jmp",
            "set_name": "Jumpstart",
            "set_type": "draft_innovation",
            "collector_number": "38★",
            "rarity": "common"
        }
        """

        var capturedURL: String?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url!.absoluteString
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, cardJSON.data(using: .utf8)!)
        }

        let card = try await service.lookupCard(setCode: "jmp", collectorNumber: "38★")

        XCTAssertEqual(card.name, "Plains")
        // URL should contain encoded star character (★ = %E2%98%85)
        XCTAssertNotNil(capturedURL)
        XCTAssertTrue(capturedURL!.contains("/cards/jmp/38%E2%98%85"))
    }

    // MARK: - Error Tests

    func testScryfallError_descriptions() {
        XCTAssertEqual(
            ScryfallError.invalidURL.errorDescription,
            "Invalid Scryfall URL."
        )

        XCTAssertEqual(
            ScryfallError.notFound.errorDescription,
            "Card not found on Scryfall."
        )

        XCTAssertEqual(
            ScryfallError.rateLimited.errorDescription,
            "Too many requests. Please wait a moment."
        )

        XCTAssertEqual(
            ScryfallError.networkError("timeout").errorDescription,
            "Network error: timeout"
        )

        XCTAssertEqual(
            ScryfallError.apiError("bad request").errorDescription,
            "Scryfall API error: bad request"
        )

        XCTAssertEqual(
            ScryfallError.decodingError("invalid json").errorDescription,
            "Failed to parse Scryfall response: invalid json"
        )
    }

    // MARK: - Additional Coverage Tests

    func testLookupFromDetection_allStrategiesFail_throwsNotFound() async throws {
        // Test that when all four lookup strategies fail, we get notFound error
        MockURLProtocol.requestHandler = { request in
            // Return 404 for all requests
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            let errorJSON = """
            {"object": "error", "code": "not_found", "status": 404, "details": "Not found"}
            """.data(using: .utf8)!
            return (response, errorJSON)
        }

        let detection = DetectionResult(
            name: "NonexistentCard",
            setCode: "xxx",
            setName: nil,
            collectorNumber: "999",
            confidence: 0.5,
            features: []
        )

        do {
            _ = try await service.lookupFromDetection(detection)
            XCTFail("Expected notFound error")
        } catch let error as ScryfallError {
            XCTAssertEqual(error, .notFound)
        }
    }

    func testLookupFromDetection_networkErrorStopsFallback() async throws {
        // Test that network errors propagate immediately without trying fallback strategies
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            // Simulate network failure on first request
            throw URLError(.notConnectedToInternet)
        }

        let detection = DetectionResult(
            name: "Lightning Bolt",
            setCode: "lea",
            setName: nil,
            collectorNumber: "161",
            confidence: 0.9,
            features: []
        )

        do {
            _ = try await service.lookupFromDetection(detection)
            XCTFail("Expected network error")
        } catch let error as ScryfallError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }

        // Should have stopped after first request
        XCTAssertEqual(requestCount, 1, "Should not attempt fallback strategies on network error")
    }

    func testLookupCard_malformedResponse_throwsDecodingError() async throws {
        // Test that malformed JSON responses result in decodingError
        mockResponse(json: "{\"invalid\": \"json\"}", statusCode: 200)

        do {
            _ = try await service.lookupCard(setCode: "lea", collectorNumber: "161")
            XCTFail("Expected decodingError")
        } catch let error as ScryfallError {
            if case .decodingError = error {
                // Expected
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    func testLookupCard_serverError_throwsApiError() async throws {
        // Test that 5xx server errors result in apiError
        let errorJSON = """
        {"object": "error", "code": "server_error", "status": 500, "details": "Internal server error"}
        """
        mockResponse(json: errorJSON, statusCode: 500)

        do {
            _ = try await service.lookupCard(setCode: "lea", collectorNumber: "161")
            XCTFail("Expected apiError")
        } catch let error as ScryfallError {
            if case .apiError(let message) = error {
                XCTAssertTrue(message.contains("Internal server error"))
            } else {
                XCTFail("Expected apiError, got \(error)")
            }
        }
    }
}
