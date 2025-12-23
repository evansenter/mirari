import Foundation

// MARK: - Scryfall Service Protocol

/// Protocol for Scryfall API operations, enabling dependency injection and testing
protocol ScryfallServiceProtocol: Sendable {
    func lookupCard(setCode: String, collectorNumber: String) async throws -> ScryfallCard
    func searchByName(_ name: String) async throws -> ScryfallCard
    func fuzzySearchByName(_ name: String) async throws -> ScryfallCard
    func search(query: String, page: Int) async throws -> ScryfallSearchResponse
    func lookupFromDetection(_ detection: DetectionResult) async throws -> ScryfallCard
}

// MARK: - Scryfall Errors

enum ScryfallError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case networkError(String)
    case notFound
    case apiError(String)
    case decodingError(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Scryfall URL."
        case .networkError(let message):
            return "Network error: \(message)"
        case .notFound:
            return "Card not found on Scryfall."
        case .apiError(let message):
            return "Scryfall API error: \(message)"
        case .decodingError(let message):
            return "Failed to parse Scryfall response: \(message)"
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        }
    }
}

// MARK: - Scryfall Service

/// Service for interacting with the Scryfall API
@MainActor
final class ScryfallService: ScryfallServiceProtocol {
    private let baseURL = "https://api.scryfall.com"
    private let session: URLSession

    /// Scryfall requires a user-agent for API requests
    private static let userAgent = "Mirari/1.0 (iOS MTG Scanner)"

    /// Default initializer with standard URLSession configuration
    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }

    /// Initializer for testing with custom URLSession
    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Primary Lookup: Set Code + Collector Number

    /// Look up a card by set code and collector number
    /// This is the most reliable way to find an exact printing
    func lookupCard(setCode: String, collectorNumber: String) async throws -> ScryfallCard {
        // Scryfall uses lowercase set codes
        let normalizedSetCode = setCode.lowercased()
        // URL-encode collector number (handles things like "123a" or "★123")
        let encodedNumber = collectorNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? collectorNumber

        let urlString = "\(baseURL)/cards/\(normalizedSetCode)/\(encodedNumber)"

        guard let url = URL(string: urlString) else {
            print("[ScryfallService] Invalid URL: \(urlString)")
            throw ScryfallError.invalidURL
        }

        return try await fetchCard(from: url)
    }

    // MARK: - Fallback: Search by Name

    /// Search for a card by name
    /// Returns the first result (usually the most recent printing)
    func searchByName(_ name: String) async throws -> ScryfallCard {
        // Use exact match first, fall back to fuzzy
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "\(baseURL)/cards/named?exact=\(encodedName)"

        guard let url = URL(string: urlString) else {
            print("[ScryfallService] Invalid search URL for name: \(name)")
            throw ScryfallError.invalidURL
        }

        return try await fetchCard(from: url)
    }

    /// Search for a card by name with fuzzy matching
    func fuzzySearchByName(_ name: String) async throws -> ScryfallCard {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "\(baseURL)/cards/named?fuzzy=\(encodedName)"

        guard let url = URL(string: urlString) else {
            print("[ScryfallService] Invalid fuzzy search URL for name: \(name)")
            throw ScryfallError.invalidURL
        }

        return try await fetchCard(from: url)
    }

    // MARK: - Full Search

    /// Search cards with a Scryfall query
    /// Example: "name:Lightning Bolt set:2xm"
    func search(query: String, page: Int = 1) async throws -> ScryfallSearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/cards/search?q=\(encodedQuery)&page=\(page)"

        guard let url = URL(string: urlString) else {
            print("[ScryfallService] Invalid search URL for query: \(query)")
            throw ScryfallError.invalidURL
        }

        return try await fetchSearchResults(from: url)
    }

    // MARK: - Smart Lookup (Detection Result -> Card)

    /// Look up a card using detection result, with fallback strategies
    /// 1. Try set code + collector number (most accurate)
    /// 2. Try name + set code search
    /// 3. Fall back to fuzzy name search
    func lookupFromDetection(_ detection: DetectionResult) async throws -> ScryfallCard {
        // Strategy 1: Exact lookup by set code and collector number
        if let setCode = detection.setCode, !setCode.isEmpty,
           let collectorNumber = detection.collectorNumber, !collectorNumber.isEmpty {
            do {
                print("[ScryfallService] Trying exact lookup: \(setCode)/\(collectorNumber)")
                let card = try await lookupCard(setCode: setCode, collectorNumber: collectorNumber)
                print("[ScryfallService] Found card via exact lookup: \(card.name)")
                return card
            } catch ScryfallError.notFound {
                print("[ScryfallService] Exact lookup failed, trying fallback...")
                // Continue to fallback
            }
        }

        // Strategy 2: Search by name + set code
        if let setCode = detection.setCode, !setCode.isEmpty {
            do {
                print("[ScryfallService] Trying name+set search: \(detection.name) set:\(setCode)")
                let query = "!\"\(detection.name)\" set:\(setCode)"
                let results = try await search(query: query)
                if let card = results.data.first {
                    print("[ScryfallService] Found card via name+set search: \(card.name)")
                    return card
                }
            } catch {
                print("[ScryfallService] Name+set search failed: \(error)")
                // Continue to fallback
            }
        }

        // Strategy 3: Exact name match
        do {
            print("[ScryfallService] Trying exact name search: \(detection.name)")
            let card = try await searchByName(detection.name)
            print("[ScryfallService] Found card via exact name: \(card.name)")
            return card
        } catch ScryfallError.notFound {
            print("[ScryfallService] Exact name not found, trying fuzzy...")
            // Continue to fuzzy
        }

        // Strategy 4: Fuzzy name match (last resort)
        print("[ScryfallService] Trying fuzzy name search: \(detection.name)")
        let card = try await fuzzySearchByName(detection.name)
        print("[ScryfallService] Found card via fuzzy search: \(card.name)")
        return card
    }

    // MARK: - Private Helpers

    private func fetchCard(from url: URL) async throws -> ScryfallCard {
        print("[ScryfallService] Fetching: \(url)")

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScryfallError.networkError("Invalid response type")
            }

            switch httpResponse.statusCode {
            case 200:
                return try decodeCard(from: data)
            case 404:
                throw ScryfallError.notFound
            case 429:
                throw ScryfallError.rateLimited
            default:
                let error = try? decodeError(from: data)
                throw ScryfallError.apiError(error?.details ?? "HTTP \(httpResponse.statusCode)")
            }
        } catch let error as ScryfallError {
            throw error
        } catch let error as URLError {
            print("[ScryfallService] Network error: \(error)")
            throw ScryfallError.networkError(error.localizedDescription)
        } catch {
            print("[ScryfallService] Unexpected error: \(error)")
            throw ScryfallError.networkError(error.localizedDescription)
        }
    }

    private func fetchSearchResults(from url: URL) async throws -> ScryfallSearchResponse {
        print("[ScryfallService] Searching: \(url)")

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScryfallError.networkError("Invalid response type")
            }

            switch httpResponse.statusCode {
            case 200:
                return try decodeSearchResults(from: data)
            case 404:
                // Empty search results
                throw ScryfallError.notFound
            case 429:
                throw ScryfallError.rateLimited
            default:
                let error = try? decodeError(from: data)
                throw ScryfallError.apiError(error?.details ?? "HTTP \(httpResponse.statusCode)")
            }
        } catch let error as ScryfallError {
            throw error
        } catch let error as URLError {
            print("[ScryfallService] Network error: \(error)")
            throw ScryfallError.networkError(error.localizedDescription)
        } catch {
            print("[ScryfallService] Unexpected error: \(error)")
            throw ScryfallError.networkError(error.localizedDescription)
        }
    }

    private func decodeCard(from data: Data) throws -> ScryfallCard {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ScryfallCard.self, from: data)
        } catch {
            print("[ScryfallService] Decoding error: \(error)")
            throw ScryfallError.decodingError(error.localizedDescription)
        }
    }

    private func decodeSearchResults(from data: Data) throws -> ScryfallSearchResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ScryfallSearchResponse.self, from: data)
        } catch {
            print("[ScryfallService] Search decoding error: \(error)")
            throw ScryfallError.decodingError(error.localizedDescription)
        }
    }

    private func decodeError(from data: Data) throws -> ScryfallErrorResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ScryfallErrorResponse.self, from: data)
    }
}
