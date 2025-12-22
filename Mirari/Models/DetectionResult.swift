import Foundation

struct DetectionResult: Sendable {
    let name: String
    let setCode: String?
    let setName: String?
    let collectorNumber: String?
    let confidence: Double
    let features: [String]

    var isLowConfidence: Bool {
        confidence < 0.7
    }

    var confidencePercentage: String {
        String(format: "%.0f%%", confidence * 100)
    }
}
