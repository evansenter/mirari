import SwiftUI

struct DetectedCardView: View {
    let capturedImage: UIImage
    let detectionResult: DetectionResult?
    let detectionError: Error?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Captured image
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                        .padding()

                    // Detection results or error
                    if let error = detectionError {
                        ErrorCard(error: error)
                    } else if let result = detectionResult {
                        ResultCard(result: result)
                    } else {
                        LoadingCard()
                    }

                    Spacer()
                }
            }
            .navigationTitle("Detected Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Result Card

private struct ResultCard: View {
    let result: DetectionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card name with confidence badge
            HStack(alignment: .top) {
                Text(result.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                ConfidenceBadge(confidence: result.confidence, isLow: result.isLowConfidence)
            }

            Divider()

            // Set info
            if let setName = result.setName {
                DetailRow(
                    icon: "square.stack.3d.up",
                    label: "Set",
                    value: result.setCode.map { "\(setName) (\($0.uppercased()))" } ?? setName
                )
            }

            // Collector number
            if let number = result.collectorNumber {
                DetailRow(icon: "number", label: "Number", value: number)
            }

            // Confidence
            DetailRow(icon: "chart.bar", label: "Confidence", value: result.confidencePercentage)

            // Features
            if !result.features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(result.features, id: \.self) { feature in
                            Text(feature.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Low confidence warning
            if result.isLowConfidence {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This identification may not be accurate. Consider retaking the photo with better lighting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

private struct ConfidenceBadge: View {
    let confidence: Double
    let isLow: Bool

    private var confidencePercentage: String {
        String(format: "%.0f%%", confidence * 100)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isLow ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            Text(confidencePercentage)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(isLow ? .orange : .green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isLow ? Color.orange : Color.green).opacity(0.15))
        .clipShape(Capsule())
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

private struct ErrorCard: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Detection Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Try taking another photo with better lighting and ensure the card is clearly visible.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

private struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Identifying card...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

#Preview("With Result") {
    DetectedCardView(
        capturedImage: UIImage(systemName: "photo")!,
        detectionResult: DetectionResult(
            name: "Lightning Bolt",
            setCode: "lea",
            setName: "Limited Edition Alpha",
            collectorNumber: "161",
            confidence: 0.95,
            features: ["Black Border"]
        ),
        detectionError: nil
    )
}

#Preview("Low Confidence") {
    DetectedCardView(
        capturedImage: UIImage(systemName: "photo")!,
        detectionResult: DetectionResult(
            name: "Unknown Card",
            setCode: nil,
            setName: nil,
            collectorNumber: nil,
            confidence: 0.45,
            features: []
        ),
        detectionError: nil
    )
}

#Preview("With Error") {
    DetectedCardView(
        capturedImage: UIImage(systemName: "photo")!,
        detectionResult: nil,
        detectionError: GeminiError.emptyResponse
    )
}
