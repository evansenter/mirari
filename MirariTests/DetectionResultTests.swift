import XCTest
@testable import Mirari

final class DetectionResultTests: XCTestCase {

    // MARK: - Confidence Tests

    func testIsLowConfidence_belowThreshold() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.5,
            features: []
        )

        XCTAssertTrue(result.isLowConfidence)
    }

    func testIsLowConfidence_atThreshold() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.7,
            features: []
        )

        XCTAssertFalse(result.isLowConfidence)
    }

    func testIsLowConfidence_aboveThreshold() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.95,
            features: []
        )

        XCTAssertFalse(result.isLowConfidence)
    }

    func testIsLowConfidence_zero() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.0,
            features: []
        )

        XCTAssertTrue(result.isLowConfidence)
    }

    // MARK: - Confidence Percentage Tests

    func testConfidencePercentage_highConfidence() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.95,
            features: []
        )

        XCTAssertEqual(result.confidencePercentage, "95%")
    }

    func testConfidencePercentage_lowConfidence() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.45,
            features: []
        )

        XCTAssertEqual(result.confidencePercentage, "45%")
    }

    func testConfidencePercentage_perfectConfidence() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 1.0,
            features: []
        )

        XCTAssertEqual(result.confidencePercentage, "100%")
    }

    func testConfidencePercentage_zeroConfidence() {
        let result = DetectionResult(
            name: "Unknown",
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.0,
            features: []
        )

        XCTAssertEqual(result.confidencePercentage, "0%")
    }

    func testConfidencePercentage_roundsCorrectly() {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.876,
            features: []
        )

        XCTAssertEqual(result.confidencePercentage, "88%")
    }

    // MARK: - Optional Fields Tests

    func testDetectionResult_withAllOptionalFieldsNil() {
        let result = DetectionResult(
            name: "Mystery Card",
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.3,
            features: []
        )

        XCTAssertEqual(result.name, "Mystery Card")
        XCTAssertNil(result.setCode)
        XCTAssertNil(result.setName)
        XCTAssertNil(result.collectorNumber)
        XCTAssertTrue(result.features.isEmpty)
    }

    func testDetectionResult_withFeatures() {
        let result = DetectionResult(
            name: "Shiny Card",
            setCode: "prm",
            setName: "Promo",
            collectorNumber: "1",
            confidence: 0.9,
            features: ["foil", "promo", "extended art"]
        )

        XCTAssertEqual(result.features.count, 3)
        XCTAssertTrue(result.features.contains("foil"))
        XCTAssertTrue(result.features.contains("promo"))
        XCTAssertTrue(result.features.contains("extended art"))
    }

    // MARK: - Sendable Conformance

    func testDetectionResult_isSendable() async {
        let result = DetectionResult(
            name: "Test Card",
            setCode: "tst",
            setName: "Test Set",
            collectorNumber: "1",
            confidence: 0.9,
            features: ["foil"]
        )

        // This test verifies Sendable conformance by passing across actor boundaries
        let task = Task.detached {
            return result.name
        }

        let name = await task.value
        XCTAssertEqual(name, "Test Card")
    }
}
