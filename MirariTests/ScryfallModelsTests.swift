import XCTest
@testable import Mirari

final class ScryfallModelsTests: XCTestCase {

    // MARK: - ScryfallCard Decoding

    func testDecodeScryfallCard_minimalFields() throws {
        let json = """
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
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.id, "abc123")
        XCTAssertEqual(card.name, "Lightning Bolt")
        XCTAssertEqual(card.set, "lea")
        XCTAssertEqual(card.setName, "Limited Edition Alpha")
        XCTAssertEqual(card.collectorNumber, "161")
        XCTAssertEqual(card.rarity, "common")
    }

    func testDecodeScryfallCard_fullFields() throws {
        let json = """
        {
            "id": "e3285e6b-3e79-4d7c-bf96-d920f973b122",
            "oracle_id": "def456",
            "name": "Lightning Bolt",
            "lang": "en",
            "released_at": "1993-08-05",
            "uri": "https://api.scryfall.com/cards/abc123",
            "scryfall_uri": "https://scryfall.com/card/lea/161",
            "layout": "normal",
            "set_id": "set123",
            "set": "lea",
            "set_name": "Limited Edition Alpha",
            "set_type": "core",
            "collector_number": "161",
            "rarity": "common",
            "mana_cost": "{R}",
            "cmc": 1.0,
            "type_line": "Instant",
            "oracle_text": "Lightning Bolt deals 3 damage to any target.",
            "colors": ["R"],
            "color_identity": ["R"],
            "keywords": [],
            "image_uris": {
                "small": "https://example.com/small.jpg",
                "normal": "https://example.com/normal.jpg",
                "large": "https://example.com/large.jpg"
            },
            "prices": {
                "usd": "450.00",
                "usd_foil": null,
                "eur": "400.00"
            },
            "foil": false,
            "nonfoil": true,
            "artist": "Christopher Rush",
            "border_color": "black",
            "frame": "1993",
            "full_art": false,
            "textless": false,
            "reserved": true
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.id, "e3285e6b-3e79-4d7c-bf96-d920f973b122")
        XCTAssertEqual(card.oracleId, "def456")
        XCTAssertEqual(card.manaCost, "{R}")
        XCTAssertEqual(card.cmc, 1.0)
        XCTAssertEqual(card.typeLine, "Instant")
        XCTAssertEqual(card.oracleText, "Lightning Bolt deals 3 damage to any target.")
        XCTAssertEqual(card.colors, ["R"])
        XCTAssertEqual(card.artist, "Christopher Rush")
        XCTAssertEqual(card.reserved, true)
        XCTAssertEqual(card.prices?.usd, "450.00")
        XCTAssertNil(card.prices?.usdFoil)
    }

    // MARK: - Double-Faced Card

    func testDecodeScryfallCard_doubleFaced() throws {
        let json = """
        {
            "id": "dfc123",
            "name": "Delver of Secrets // Insectile Aberration",
            "lang": "en",
            "uri": "https://api.scryfall.com/cards/dfc123",
            "scryfall_uri": "https://scryfall.com/card/isd/51",
            "layout": "transform",
            "set_id": "set456",
            "set": "isd",
            "set_name": "Innistrad",
            "set_type": "expansion",
            "collector_number": "51",
            "rarity": "common",
            "card_faces": [
                {
                    "name": "Delver of Secrets",
                    "mana_cost": "{U}",
                    "type_line": "Creature — Human Wizard",
                    "oracle_text": "At the beginning of your upkeep...",
                    "power": "1",
                    "toughness": "1",
                    "image_uris": {
                        "normal": "https://example.com/front.jpg"
                    }
                },
                {
                    "name": "Insectile Aberration",
                    "type_line": "Creature — Human Insect",
                    "oracle_text": "Flying",
                    "power": "3",
                    "toughness": "2",
                    "image_uris": {
                        "normal": "https://example.com/back.jpg"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.layout, "transform")
        XCTAssertEqual(card.cardFaces?.count, 2)
        XCTAssertEqual(card.cardFaces?[0].name, "Delver of Secrets")
        XCTAssertEqual(card.cardFaces?[0].power, "1")
        XCTAssertEqual(card.cardFaces?[1].name, "Insectile Aberration")
        XCTAssertEqual(card.cardFaces?[1].power, "3")
    }

    // MARK: - Convenience Methods

    func testBestImageUrl_singleFaced() throws {
        let json = """
        {
            "id": "abc",
            "name": "Test",
            "lang": "en",
            "uri": "https://example.com",
            "scryfall_uri": "https://example.com",
            "layout": "normal",
            "set_id": "set",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common",
            "image_uris": {
                "small": "https://example.com/small.jpg",
                "normal": "https://example.com/normal.jpg",
                "large": "https://example.com/large.jpg"
            }
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.bestImageUrl, "https://example.com/normal.jpg")
    }

    func testBestImageUrl_doubleFaced() throws {
        let json = """
        {
            "id": "abc",
            "name": "Test // Back",
            "lang": "en",
            "uri": "https://example.com",
            "scryfall_uri": "https://example.com",
            "layout": "transform",
            "set_id": "set",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common",
            "card_faces": [
                {
                    "name": "Test",
                    "image_uris": {
                        "normal": "https://example.com/front.jpg"
                    }
                },
                {
                    "name": "Back",
                    "image_uris": {
                        "normal": "https://example.com/back.jpg"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        // Should return front face image
        XCTAssertEqual(card.bestImageUrl, "https://example.com/front.jpg")
    }

    func testFullOracleText_singleFaced() throws {
        let json = """
        {
            "id": "abc",
            "name": "Test",
            "lang": "en",
            "uri": "https://example.com",
            "scryfall_uri": "https://example.com",
            "layout": "normal",
            "set_id": "set",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common",
            "oracle_text": "This is the oracle text."
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.fullOracleText, "This is the oracle text.")
    }

    func testFullOracleText_doubleFaced() throws {
        let json = """
        {
            "id": "abc",
            "name": "Test // Back",
            "lang": "en",
            "uri": "https://example.com",
            "scryfall_uri": "https://example.com",
            "layout": "transform",
            "set_id": "set",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common",
            "card_faces": [
                {
                    "name": "Test",
                    "oracle_text": "Front text."
                },
                {
                    "name": "Back",
                    "oracle_text": "Back text."
                }
            ]
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.fullOracleText, "Front text.\n\n// \n\nBack text.")
    }

    // MARK: - Prices

    func testPricesToJsonString() throws {
        let prices = Prices(
            usd: "10.00",
            usdFoil: "25.00",
            usdEtched: nil,
            eur: "8.50",
            eurFoil: nil,
            tix: "2.5"
        )

        let jsonString = prices.toJsonString()
        XCTAssertNotNil(jsonString)

        // Verify it can be decoded back
        let data = jsonString!.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Prices.self, from: data)
        XCTAssertEqual(decoded.usd, "10.00")
        XCTAssertEqual(decoded.usdFoil, "25.00")
    }

    func testFormattedPrice() throws {
        let json = """
        {
            "id": "abc",
            "name": "Test",
            "lang": "en",
            "uri": "https://example.com",
            "scryfall_uri": "https://example.com",
            "layout": "normal",
            "set_id": "set",
            "set": "tst",
            "set_name": "Test Set",
            "set_type": "core",
            "collector_number": "1",
            "rarity": "common",
            "prices": {
                "usd": "15.50",
                "usd_foil": "45.00"
            }
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(ScryfallCard.self, from: json)

        XCTAssertEqual(card.formattedPrice, "$15.50")
        XCTAssertEqual(card.formattedFoilPrice, "$45.00")
    }

    // MARK: - Search Response

    func testDecodeSearchResponse() throws {
        let json = """
        {
            "object": "list",
            "total_cards": 2,
            "has_more": false,
            "data": [
                {
                    "id": "card1",
                    "name": "Lightning Bolt",
                    "lang": "en",
                    "uri": "https://example.com/1",
                    "scryfall_uri": "https://example.com/1",
                    "layout": "normal",
                    "set_id": "set1",
                    "set": "2xm",
                    "set_name": "Double Masters",
                    "set_type": "masters",
                    "collector_number": "117",
                    "rarity": "uncommon"
                },
                {
                    "id": "card2",
                    "name": "Lightning Bolt",
                    "lang": "en",
                    "uri": "https://example.com/2",
                    "scryfall_uri": "https://example.com/2",
                    "layout": "normal",
                    "set_id": "set2",
                    "set": "lea",
                    "set_name": "Limited Edition Alpha",
                    "set_type": "core",
                    "collector_number": "161",
                    "rarity": "common"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ScryfallSearchResponse.self, from: json)

        XCTAssertEqual(response.object, "list")
        XCTAssertEqual(response.totalCards, 2)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.data[0].set, "2xm")
        XCTAssertEqual(response.data[1].set, "lea")
    }

    // MARK: - Error Response

    func testDecodeErrorResponse() throws {
        let json = """
        {
            "object": "error",
            "code": "not_found",
            "status": 404,
            "details": "No card found with the given ID."
        }
        """.data(using: .utf8)!

        let error = try JSONDecoder().decode(ScryfallErrorResponse.self, from: json)

        XCTAssertEqual(error.object, "error")
        XCTAssertEqual(error.code, "not_found")
        XCTAssertEqual(error.status, 404)
        XCTAssertEqual(error.details, "No card found with the given ID.")
    }
}
