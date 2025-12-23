import SwiftUI
import SwiftData

struct DetectedCardView: View {
    let capturedImage: UIImage
    let detectionResult: DetectionResult?
    let scryfallCard: ScryfallCard?
    let detectionError: Error?
    let scryfallError: Error?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isFoil = false
    @State private var quantity = 1
    @State private var condition = "NM"
    @State private var showingSaveConfirmation = false

    private let conditions = ["NM", "LP", "MP", "HP", "DMG"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Card image: prefer Scryfall image, fall back to captured photo
                    cardImageSection

                    // Detection results or error
                    if let error = detectionError {
                        ErrorCard(error: error)
                    } else if let result = detectionResult {
                        cardDetailsSection(result: result)
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
            .alert("Added to Collection", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let card = scryfallCard {
                    Text("\(card.name) has been added to your collection.")
                } else if let result = detectionResult {
                    Text("\(result.name) has been added to your collection.")
                }
            }
        }
    }

    // MARK: - Card Image Section

    @ViewBuilder
    private var cardImageSection: some View {
        if let imageUrl = scryfallCard?.bestImageUrl, let url = URL(string: imageUrl) {
            // Show Scryfall card image
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(height: 300)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                case .failure:
                    // Fall back to captured image on failure
                    capturedImageView
                @unknown default:
                    capturedImageView
                }
            }
            .padding()
        } else {
            // Show captured image
            capturedImageView
        }
    }

    private var capturedImageView: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding()
    }

    // MARK: - Card Details Section

    @ViewBuilder
    private func cardDetailsSection(result: DetectionResult) -> some View {
        VStack(spacing: 16) {
            // Main result card with Scryfall enrichment
            ResultCard(result: result, scryfallCard: scryfallCard)

            // Scryfall unavailable warning
            if scryfallCard == nil {
                ScryfallUnavailableCard(error: scryfallError)
            }

            // Oracle text section (if available from Scryfall)
            if let oracleText = scryfallCard?.fullOracleText, !oracleText.isEmpty {
                OracleTextCard(text: oracleText)
            }

            // Price section (if available from Scryfall)
            if let card = scryfallCard, card.prices != nil {
                PriceCard(card: card)
            }

            // Collection options
            if canSaveToCollection {
                CollectionOptionsCard(
                    isFoil: $isFoil,
                    quantity: $quantity,
                    condition: $condition,
                    conditions: conditions,
                    hasFoilPrinting: scryfallCard?.foil ?? true
                )

                // Save button
                Button(action: saveToCollection) {
                    Label("Add to Collection", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Save Logic

    private var canSaveToCollection: Bool {
        // Can save if we have Scryfall data, or at least Gemini detection with set info
        if scryfallCard != nil {
            return true
        }
        if let result = detectionResult,
           result.setCode != nil,
           result.collectorNumber != nil {
            return true
        }
        return false
    }

    private func saveToCollection() {
        let card: Card

        if let scryfall = scryfallCard {
            // Create card from Scryfall data (preferred)
            card = Card(
                scryfallId: scryfall.id,
                name: scryfall.name,
                setCode: scryfall.set,
                setName: scryfall.setName,
                collectorNumber: scryfall.collectorNumber,
                imageUrl: scryfall.bestImageUrl,
                oracleText: scryfall.fullOracleText,
                manaCost: scryfall.manaCost,
                typeLine: scryfall.typeLine,
                rarity: scryfall.rarity,
                quantity: quantity,
                isFoil: isFoil,
                condition: condition,
                pricesJson: scryfall.prices?.toJsonString()
            )
        } else if let result = detectionResult {
            // Fall back to Gemini detection data
            card = Card(
                scryfallId: UUID().uuidString, // Temporary ID
                name: result.name,
                setCode: result.setCode ?? "unknown",
                setName: result.setName ?? "Unknown Set",
                collectorNumber: result.collectorNumber ?? "0",
                quantity: quantity,
                isFoil: isFoil,
                condition: condition
            )
        } else {
            return
        }

        modelContext.insert(card)
        print("[DetectedCardView] Saved card: \(card.name) to collection")
        showingSaveConfirmation = true
    }
}

// MARK: - Result Card

private struct ResultCard: View {
    let result: DetectionResult
    let scryfallCard: ScryfallCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card name with confidence badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scryfallCard?.name ?? result.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Type line from Scryfall
                    if let typeLine = scryfallCard?.typeLine {
                        Text(typeLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                ConfidenceBadge(confidence: result.confidence, isLow: result.isLowConfidence)
            }

            // Mana cost from Scryfall
            if let manaCost = scryfallCard?.manaCost, !manaCost.isEmpty {
                HStack {
                    Text("Mana Cost")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manaCost)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Divider()

            // Set info
            let setName = scryfallCard?.setName ?? result.setName
            let setCode = scryfallCard?.set ?? result.setCode
            if let setName = setName {
                DetailRow(
                    icon: "square.stack.3d.up",
                    label: "Set",
                    value: setCode.map { "\(setName) (\($0.uppercased()))" } ?? setName
                )
            }

            // Collector number
            let number = scryfallCard?.collectorNumber ?? result.collectorNumber
            if let number = number {
                DetailRow(icon: "number", label: "Number", value: number)
            }

            // Rarity from Scryfall
            if let rarity = scryfallCard?.rarity {
                DetailRow(icon: "sparkles", label: "Rarity", value: rarity.capitalized)
            }

            // Artist from Scryfall
            if let artist = scryfallCard?.artist {
                DetailRow(icon: "paintbrush", label: "Artist", value: artist)
            }

            // Features from Gemini
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

// MARK: - Oracle Text Card

private struct OracleTextCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Oracle Text", systemImage: "text.quote")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Price Card

private struct PriceCard: View {
    let card: ScryfallCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Prices", systemImage: "dollarsign.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let price = card.prices?.usd {
                    PriceItem(label: "Regular", price: "$\(price)")
                }
                if let foilPrice = card.prices?.usdFoil {
                    PriceItem(label: "Foil", price: "$\(foilPrice)")
                }
                if card.prices?.usd == nil && card.prices?.usdFoil == nil {
                    Text("No price data available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

private struct PriceItem: View {
    let label: String
    let price: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(price)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Collection Options Card

private struct CollectionOptionsCard: View {
    @Binding var isFoil: Bool
    @Binding var quantity: Int
    @Binding var condition: String
    let conditions: [String]
    let hasFoilPrinting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Collection Options", systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Quantity stepper
            HStack {
                Text("Quantity")
                Spacer()
                Stepper("\(quantity)", value: $quantity, in: 1...99)
                    .labelsHidden()
                Text("\(quantity)")
                    .fontWeight(.medium)
                    .frame(width: 30)
            }

            // Condition picker
            HStack {
                Text("Condition")
                Spacer()
                Picker("Condition", selection: $condition) {
                    ForEach(conditions, id: \.self) { cond in
                        Text(cond).tag(cond)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            // Foil toggle
            if hasFoilPrinting {
                Toggle("Foil", isOn: $isFoil)
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

private struct ScryfallUnavailableCard: View {
    let error: Error?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Card Data")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var errorMessage: String {
        if let scryfallError = error as? ScryfallError {
            switch scryfallError {
            case .networkError:
                return "Network unavailable. Prices and high-res images not loaded."
            case .notFound:
                return "Card not found on Scryfall. This may be a new or special printing."
            case .rateLimited:
                return "Too many requests. Please try again in a moment."
            default:
                return "Could not fetch full card details from Scryfall."
            }
        }
        if error != nil {
            return "Could not fetch full card details. Prices and images unavailable."
        }
        return "Scryfall data unavailable. Prices and high-res images not loaded."
    }
}

#Preview("With Scryfall Data") {
    let sampleCard = ScryfallCard(
        id: "abc123",
        oracleId: "def456",
        name: "Lightning Bolt",
        lang: "en",
        releasedAt: "1993-08-05",
        uri: "https://api.scryfall.com/cards/abc123",
        scryfallUri: "https://scryfall.com/card/lea/161",
        layout: "normal",
        setId: "set123",
        set: "lea",
        setName: "Limited Edition Alpha",
        setType: "core",
        collectorNumber: "161",
        rarity: "common",
        manaCost: "{R}",
        cmc: 1,
        typeLine: "Instant",
        oracleText: "Lightning Bolt deals 3 damage to any target.",
        power: nil,
        toughness: nil,
        colors: ["R"],
        colorIdentity: ["R"],
        keywords: nil,
        imageUris: ImageUris(
            small: nil,
            normal: "https://cards.scryfall.io/normal/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg",
            large: nil,
            png: nil,
            artCrop: nil,
            borderCrop: nil
        ),
        cardFaces: nil,
        prices: Prices(usd: "450.00", usdFoil: nil, usdEtched: nil, eur: "400.00", eurFoil: nil, tix: nil),
        legalities: nil,
        foil: false,
        nonfoil: true,
        oversized: false,
        promo: false,
        reprint: false,
        variation: false,
        digital: false,
        artist: "Christopher Rush",
        borderColor: "black",
        frame: "1993",
        fullArt: false,
        textless: false,
        reserved: true
    )

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
        scryfallCard: sampleCard,
        detectionError: nil,
        scryfallError: nil
    )
    .modelContainer(for: Card.self, inMemory: true)
}

#Preview("Gemini Only") {
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
        scryfallCard: nil,
        detectionError: nil,
        scryfallError: ScryfallError.networkError("Connection failed")
    )
    .modelContainer(for: Card.self, inMemory: true)
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
        scryfallCard: nil,
        detectionError: nil,
        scryfallError: nil
    )
    .modelContainer(for: Card.self, inMemory: true)
}

#Preview("With Error") {
    DetectedCardView(
        capturedImage: UIImage(systemName: "photo")!,
        detectionResult: nil,
        scryfallCard: nil,
        detectionError: GeminiError.emptyResponse,
        scryfallError: nil
    )
    .modelContainer(for: Card.self, inMemory: true)
}
