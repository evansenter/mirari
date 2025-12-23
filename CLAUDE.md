# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mirari is an iOS app for Magic: The Gathering card recognition and collection management. It uses Gemini AI to identify cards by their artwork (not just text), looks them up on Scryfall, and manages a personal collection.

**Key Differentiator**: Uses card art to identify specific printings/versions, unlike existing apps that rely on OCR text matching.

## Technology Stack

- **UI**: SwiftUI
- **Data**: SwiftData
- **Camera**: AVFoundation
- **AI**: Gemini 3 Flash Preview (frame-by-frame) + Gemini 2.5 Flash Live API (streaming)
- **Cards**: Scryfall API
- **Min iOS**: 17.0 (required for SwiftData)

## Build Commands

**Generate/regenerate Xcode project:**
```bash
xcodegen generate
```

**Open in Xcode:**
```bash
open Mirari.xcodeproj
```

## Architecture

```
Mirari/
├── App/
│   ├── MirariApp.swift              # App entry point
│   └── ContentView.swift            # Tab-based navigation
├── Features/
│   ├── Scanner/
│   │   ├── ScannerView.swift        # Camera UI with card detection
│   │   ├── CameraManager.swift      # AVFoundation camera handling
│   │   ├── CardDetectionService.swift # Orchestrates AI + Scryfall
│   │   └── DetectedCardView.swift   # Shows detected card details
│   ├── Collection/
│   │   ├── CollectionView.swift     # Grid of collected cards
│   │   ├── CardDetailView.swift     # Single card view
│   │   └── ImportExportView.swift   # CSV handling
│   └── Similar/
│       └── SimilarCardsView.swift   # AI-powered similar cards (future)
├── Services/
│   ├── Gemini/
│   │   ├── GeminiService.swift      # Protocol for AI detection
│   │   ├── GeminiFrameService.swift # Frame-by-frame with 3 Flash
│   │   └── GeminiLiveService.swift  # WebSocket streaming with 2.5 Flash
│   └── Scryfall/
│       ├── ScryfallService.swift    # API client
│       └── ScryfallModels.swift     # Card, Set DTOs
├── Models/
│   ├── Card.swift                   # SwiftData model for collection
│   └── ScanResult.swift             # Detection result type
└── Utilities/
    └── APIKeys.swift                # Secure key storage (gitignored)
```

### Key Design Decisions

1. **Protocol-based AI service**: `GeminiService` protocol allows swapping between frame-by-frame and streaming implementations
2. **Scryfall as source of truth**: AI identifies cards, Scryfall provides authoritative data
3. **Confidence scoring**: AI returns confidence level, we can require minimum threshold
4. **Offline-first collection**: SwiftData stores full card data, not just references

## Firebase Setup

This app uses Firebase AI Logic for Gemini API access. Firebase must be configured:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **AI Logic** and select **Gemini Developer API**
3. Register iOS app with bundle ID `com.mirari.app`
4. Download `GoogleService-Info.plist` and place in `Mirari/` folder
5. Run `xcodegen generate` to include it in the project

The `GoogleService-Info.plist` file is gitignored for security.

## Dependencies

- **Firebase iOS SDK** (v12.5+) - FirebaseCore + FirebaseAILogic

## Testing on Device

Camera features require a physical iPhone. Simulator won't work for scanning.

1. Connect iPhone via USB
2. In Xcode: Select your iPhone from device dropdown
3. First time: Trust the developer certificate on iPhone (Settings > General > Device Management)
4. Build and run (Cmd+R)

---

## Implementation Roadmap

- [x] **Phase 1**: Project setup & camera preview
- [x] **Phase 2**: Gemini Frame-by-Frame detection (gemini-3-flash-preview)
- [ ] **Phase 3**: Scryfall API integration
- [ ] **Phase 4**: Collection management with SwiftData
- [ ] **Phase 5**: Gemini Live API streaming (Gemini 2.5 Flash)
- [ ] **Phase 6**: CSV import/export

---

## Phase 2: Gemini Frame-by-Frame Detection

**Goal**: Tap to capture a frame, send to Gemini 3 Flash, get card identification

**Gemini Prompt Strategy**:
```
You are a Magic: The Gathering card identifier. Analyze this image and identify:
1. Card name
2. Set name and code (e.g., "Dominaria United" / "dmu")
3. Collector number
4. Any distinguishing features (foil, promo, art variant)

Focus on the card art, frame style, and set symbol to determine the exact printing.
Return as JSON: {"name": "", "set_code": "", "set_name": "", "collector_number": "", "confidence": 0.0-1.0}
```

**Files to create**:
- `Mirari/Services/Gemini/GeminiService.swift` (protocol)
- `Mirari/Services/Gemini/GeminiFrameService.swift`

---

## Phase 3: Scryfall Integration

**Goal**: Look up identified cards on Scryfall, display full card data

**Key Scryfall Endpoints**:
- `GET /cards/:set/:number` - Primary lookup by set code + collector number
- `GET /cards/search?q=name:X` - Fallback search by name
- `GET /cards/collection` - Bulk lookup

**Files to create**:
- `Mirari/Services/Scryfall/ScryfallService.swift`
- `Mirari/Services/Scryfall/ScryfallModels.swift`

---

## Phase 4: Collection Management

**Goal**: Save cards to collection, view collection, basic management

**Card Model Fields** (already exists in Card.swift):
- scryfallId, name, setCode, setName, collectorNumber
- imageUrl, oracleText, manaCost, typeLine, rarity
- quantity, condition, isFoil, dateAdded
- pricesJson

**Files to create**:
- `Mirari/Features/Collection/CardDetailView.swift`

---

## Phase 5: Gemini Live API (Streaming)

**Goal**: Add real-time streaming detection as alternative mode

**Pre-requisite Refactor**: Before implementing Live API, refactor GeminiService to use protocol-based architecture:
1. Create `CardDetectionService` protocol with `func detectCard(from image: UIImage) async throws -> DetectionResult`
2. Rename current `GeminiService` to `GeminiFrameService` implementing the protocol
3. Update `ScannerView` to depend on `any CardDetectionService` instead of concrete class
4. This enables swapping between Frame and Live implementations seamlessly

**Live API Notes**:
- Uses `gemini-2.5-flash-preview` (Live API doesn't support 3 Flash yet)
- WebSocket endpoint: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent`
- Send frames as base64-encoded JPEG at ~1 FPS

**Files to create**:
- `Mirari/Services/Gemini/CardDetectionService.swift` (protocol)
- `Mirari/Services/Gemini/GeminiLiveService.swift`

---

## Phase 6: CSV Import/Export

**Goal**: Export collection to CSV, import from other apps (Deckbox, Moxfield, etc.)

**CSV Format**:
```csv
name,set_code,collector_number,quantity,condition,foil
"Lightning Bolt","2xm","117",4,"NM",false
```

**Files to create**:
- `Mirari/Features/Collection/ImportExportView.swift`
- `Mirari/Services/CSVService.swift`

---

## Future Features (Stretch)

- Similar cards using AI (based on mechanics, art style, color)
- Card generation with Imagen 3
- iCloud sync
- Deck building
- Price tracking
