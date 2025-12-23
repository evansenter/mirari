import XCTest
@testable import Mirari

@MainActor
final class GeminiServiceTests: XCTestCase {

    var service: GeminiService!

    override func setUp() async throws {
        try await super.setUp()
        service = GeminiService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Parse Response Tests

    func testParseResponse_validJSON() throws {
        let json = """
        {"name": "Lightning Bolt", "set_code": "lea", "set_name": "Limited Edition Alpha", "collector_number": "161", "confidence": 0.95, "features": ["foil"]}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.name, "Lightning Bolt")
        XCTAssertEqual(result.setCode, "lea")
        XCTAssertEqual(result.setName, "Limited Edition Alpha")
        XCTAssertEqual(result.collectorNumber, "161")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.features, ["foil"])
    }

    func testParseResponse_withMarkdownCodeBlock() throws {
        let json = """
        ```json
        {"name": "Counterspell", "set_code": "lea", "set_name": "Limited Edition Alpha", "collector_number": "54", "confidence": 0.88, "features": []}
        ```
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.name, "Counterspell")
        XCTAssertEqual(result.setCode, "lea")
        XCTAssertEqual(result.confidence, 0.88)
    }

    func testParseResponse_withExtraTextAroundJSON() throws {
        let json = """
        Based on my analysis, here is the card information:
        {"name": "Dark Ritual", "set_code": "lea", "set_name": "Limited Edition Alpha", "collector_number": "98", "confidence": 0.92, "features": []}
        I hope this helps!
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.name, "Dark Ritual")
        XCTAssertEqual(result.setCode, "lea")
    }

    func testParseResponse_minimalFields() throws {
        let json = """
        {"name": "Unknown Card", "confidence": 0.3}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.name, "Unknown Card")
        XCTAssertNil(result.setCode)
        XCTAssertNil(result.setName)
        XCTAssertNil(result.collectorNumber)
        XCTAssertEqual(result.confidence, 0.3)
        XCTAssertTrue(result.features.isEmpty)
    }

    func testParseResponse_clampsConfidenceAbove1() throws {
        let json = """
        {"name": "Test Card", "confidence": 1.5}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.confidence, 1.0)
    }

    func testParseResponse_clampsConfidenceBelow0() throws {
        let json = """
        {"name": "Test Card", "confidence": -0.5}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.confidence, 0.0)
    }

    func testParseResponse_defaultsConfidenceToZero() throws {
        let json = """
        {"name": "Test Card"}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.confidence, 0.0)
    }

    func testParseResponse_multipleFeatures() throws {
        let json = """
        {"name": "Promo Card", "set_code": "prm", "confidence": 0.85, "features": ["foil", "promo", "showcase", "extended art"]}
        """

        let result = try service.parseResponse(json)

        XCTAssertEqual(result.features.count, 4)
        XCTAssertTrue(result.features.contains("foil"))
        XCTAssertTrue(result.features.contains("promo"))
        XCTAssertTrue(result.features.contains("showcase"))
        XCTAssertTrue(result.features.contains("extended art"))
    }

    // MARK: - Parse Response Error Cases

    func testParseResponse_missingName_throwsError() {
        let json = """
        {"set_code": "lea", "confidence": 0.9}
        """

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("name"))
        }
    }

    func testParseResponse_emptyName_throwsError() {
        let json = """
        {"name": "", "set_code": "lea", "confidence": 0.9}
        """

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("name"))
        }
    }

    func testParseResponse_invalidJSON_throwsError() {
        let json = "this is not json"

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
        }
    }

    func testParseResponse_arrayInsteadOfObject_throwsError() {
        let json = """
        [{"name": "Card 1"}, {"name": "Card 2"}]
        """

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("object"))
        }
    }

    func testParseResponse_emptyString_throwsError() {
        let json = ""

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
        }
    }

    func testParseResponse_whitespaceOnly_throwsError() {
        let json = "   \n\t  "

        XCTAssertThrowsError(try service.parseResponse(json)) { error in
            guard case GeminiError.parsingFailed = error else {
                XCTFail("Expected parsingFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - GeminiError Tests

    func testGeminiError_errorDescriptions() {
        XCTAssertEqual(
            GeminiError.imageConversionFailed.errorDescription,
            "Failed to process the captured image."
        )

        XCTAssertEqual(
            GeminiError.emptyResponse.errorDescription,
            "No response received from AI."
        )

        XCTAssertEqual(
            GeminiError.parsingFailed("test error").errorDescription,
            "Could not parse AI response: test error"
        )

        XCTAssertEqual(
            GeminiError.apiError("network issue").errorDescription,
            "API error: network issue"
        )
    }
}
