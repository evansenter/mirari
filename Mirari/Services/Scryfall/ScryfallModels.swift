import Foundation

// MARK: - Scryfall Card Response

/// Full card data from Scryfall API
struct ScryfallCard: Codable, Sendable {
    let id: String
    let oracleId: String?
    let name: String
    let lang: String
    let releasedAt: String?
    let uri: String
    let scryfallUri: String
    let layout: String

    // Set information
    let setId: String
    let set: String  // set code
    let setName: String
    let setType: String
    let collectorNumber: String
    let rarity: String

    // Card details
    let manaCost: String?
    let cmc: Double?
    let typeLine: String?
    let oracleText: String?
    let power: String?
    let toughness: String?
    let colors: [String]?
    let colorIdentity: [String]?
    let keywords: [String]?

    // Images
    let imageUris: ImageUris?
    let cardFaces: [CardFace]?

    // Prices
    let prices: Prices?

    // Legalities
    let legalities: [String: String]?

    // Misc
    let foil: Bool?
    let nonfoil: Bool?
    let oversized: Bool?
    let promo: Bool?
    let reprint: Bool?
    let variation: Bool?
    let digital: Bool?
    let artist: String?
    let borderColor: String?
    let frame: String?
    let fullArt: Bool?
    let textless: Bool?
    let reserved: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case oracleId = "oracle_id"
        case name
        case lang
        case releasedAt = "released_at"
        case uri
        case scryfallUri = "scryfall_uri"
        case layout
        case setId = "set_id"
        case set
        case setName = "set_name"
        case setType = "set_type"
        case collectorNumber = "collector_number"
        case rarity
        case manaCost = "mana_cost"
        case cmc
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case power
        case toughness
        case colors
        case colorIdentity = "color_identity"
        case keywords
        case imageUris = "image_uris"
        case cardFaces = "card_faces"
        case prices
        case legalities
        case foil
        case nonfoil
        case oversized
        case promo
        case reprint
        case variation
        case digital
        case artist
        case borderColor = "border_color"
        case frame
        case fullArt = "full_art"
        case textless
        case reserved
    }
}

// MARK: - Image URIs

struct ImageUris: Codable, Sendable {
    let small: String?
    let normal: String?
    let large: String?
    let png: String?
    let artCrop: String?
    let borderCrop: String?

    enum CodingKeys: String, CodingKey {
        case small
        case normal
        case large
        case png
        case artCrop = "art_crop"
        case borderCrop = "border_crop"
    }
}

// MARK: - Card Face (for double-faced cards)

struct CardFace: Codable, Sendable {
    let name: String
    let manaCost: String?
    let typeLine: String?
    let oracleText: String?
    let power: String?
    let toughness: String?
    let imageUris: ImageUris?
    let artist: String?

    enum CodingKeys: String, CodingKey {
        case name
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case power
        case toughness
        case imageUris = "image_uris"
        case artist
    }
}

// MARK: - Prices

struct Prices: Codable, Sendable {
    let usd: String?
    let usdFoil: String?
    let usdEtched: String?
    let eur: String?
    let eurFoil: String?
    let tix: String?

    enum CodingKeys: String, CodingKey {
        case usd
        case usdFoil = "usd_foil"
        case usdEtched = "usd_etched"
        case eur
        case eurFoil = "eur_foil"
        case tix
    }

    /// Convert prices to JSON string for storage
    func toJsonString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - Search Response

struct ScryfallSearchResponse: Codable, Sendable {
    let object: String
    let totalCards: Int
    let hasMore: Bool
    let data: [ScryfallCard]

    enum CodingKeys: String, CodingKey {
        case object
        case totalCards = "total_cards"
        case hasMore = "has_more"
        case data
    }
}

// MARK: - Error Response

struct ScryfallErrorResponse: Codable, Sendable {
    let object: String
    let code: String
    let status: Int
    let details: String
}

// MARK: - Convenience Extensions

extension ScryfallCard {
    /// Get the best available image URL (prefers normal size)
    var bestImageUrl: String? {
        // For single-faced cards
        if let imageUris = imageUris {
            return imageUris.normal ?? imageUris.large ?? imageUris.small
        }
        // For double-faced cards, use front face
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.imageUris?.normal ?? firstFace.imageUris?.large ?? firstFace.imageUris?.small
        }
        return nil
    }

    /// Get combined oracle text for double-faced cards
    var fullOracleText: String? {
        if let text = oracleText {
            return text
        }
        // Combine text from both faces
        if let faces = cardFaces {
            let texts = faces.compactMap { $0.oracleText }
            return texts.isEmpty ? nil : texts.joined(separator: "\n\n// \n\n")
        }
        return nil
    }

    /// Get the USD price as a formatted string
    var formattedPrice: String? {
        if let usd = prices?.usd {
            return "$\(usd)"
        }
        return nil
    }

    /// Get the foil USD price as a formatted string
    var formattedFoilPrice: String? {
        if let usdFoil = prices?.usdFoil {
            return "$\(usdFoil)"
        }
        return nil
    }
}
