import FirebaseAILogic
import UIKit

enum GeminiError: LocalizedError, Sendable {
    case imageConversionFailed
    case emptyResponse
    case parsingFailed(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the captured image."
        case .emptyResponse:
            return "No response received from AI."
        case .parsingFailed(let detail):
            return "Could not parse AI response: \(detail)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

@MainActor
final class GeminiService {
    private let model: GenerativeModel

    init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        self.model = ai.generativeModel(modelName: "gemini-3-flash-preview")
    }

    func identifyCard(image: UIImage) async throws -> DetectionResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageConversionFailed
        }

        let prompt = """
        You are a Magic: The Gathering card identifier. Analyze this image and identify the card.

        Focus on:
        1. Card name (exact spelling)
        2. Set name and set code (e.g., "Dominaria United" / "dmu")
        3. Collector number (the number at bottom of card)
        4. Any distinguishing features (foil, promo, extended art, showcase, etc.)

        Pay close attention to the card art, frame style, and set symbol to determine the exact printing.

        Return ONLY a JSON object with this exact structure (no markdown, no code blocks):
        {"name": "Card Name", "set_code": "abc", "set_name": "Set Name", "collector_number": "123", "confidence": 0.95, "features": ["foil"]}

        The confidence should be between 0.0 and 1.0. If you cannot identify the card, still provide your best guess with a lower confidence score.
        """

        do {
            let response = try await model.generateContent(
                InlineDataPart(data: imageData, mimeType: "image/jpeg"),
                prompt
            )

            guard let text = response.text, !text.isEmpty else {
                throw GeminiError.emptyResponse
            }

            return try parseResponse(text)
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.apiError(error.localizedDescription)
        }
    }

    private func parseResponse(_ text: String) throws -> DetectionResult {
        // Clean response - remove markdown code blocks if present
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract JSON if there's extra text around it
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.parsingFailed("Invalid text encoding")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.parsingFailed("Invalid JSON structure")
        }

        let name = json["name"] as? String ?? "Unknown Card"
        let setCode = json["set_code"] as? String
        let setName = json["set_name"] as? String
        let collectorNumber = json["collector_number"] as? String
        let confidence = json["confidence"] as? Double ?? 0.0
        let features = json["features"] as? [String] ?? []

        return DetectionResult(
            name: name,
            setCode: setCode,
            setName: setName,
            collectorNumber: collectorNumber,
            confidence: confidence,
            features: features
        )
    }
}
