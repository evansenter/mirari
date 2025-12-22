import Foundation
import SwiftData

@Model
final class Card {
    var scryfallId: String
    var name: String
    var setCode: String
    var setName: String
    var collectorNumber: String
    var imageUrl: String?
    var oracleText: String?
    var manaCost: String?
    var typeLine: String?
    var rarity: String?

    // Collection-specific
    var quantity: Int
    var isFoil: Bool
    var condition: String
    var dateAdded: Date

    // Price info (stored as JSON string for flexibility)
    var pricesJson: String?

    init(
        scryfallId: String,
        name: String,
        setCode: String,
        setName: String,
        collectorNumber: String,
        imageUrl: String? = nil,
        oracleText: String? = nil,
        manaCost: String? = nil,
        typeLine: String? = nil,
        rarity: String? = nil,
        quantity: Int = 1,
        isFoil: Bool = false,
        condition: String = "NM",
        dateAdded: Date = Date(),
        pricesJson: String? = nil
    ) {
        self.scryfallId = scryfallId
        self.name = name
        self.setCode = setCode
        self.setName = setName
        self.collectorNumber = collectorNumber
        self.imageUrl = imageUrl
        self.oracleText = oracleText
        self.manaCost = manaCost
        self.typeLine = typeLine
        self.rarity = rarity
        self.quantity = quantity
        self.isFoil = isFoil
        self.condition = condition
        self.dateAdded = dateAdded
        self.pricesJson = pricesJson
    }
}
