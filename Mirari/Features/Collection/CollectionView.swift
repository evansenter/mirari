import SwiftUI
import SwiftData

struct CollectionView: View {
    @Query(sort: \Card.dateAdded, order: .reverse) private var cards: [Card]
    @Environment(\.modelContext) private var modelContext

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    EmptyCollectionView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(cards) { card in
                                CardGridItem(card: card)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Collection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            // TODO: Import CSV
                        } label: {
                            Label("Import CSV", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            // TODO: Export CSV
                        } label: {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct EmptyCollectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Cards", systemImage: "square.stack.3d.up.slash")
        } description: {
            Text("Scan cards to add them to your collection.")
        } actions: {
            Text("Go to the Scan tab to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CardGridItem: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Card image placeholder
            AsyncImage(url: URL(string: card.imageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .aspectRatio(0.714, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .aspectRatio(0.714, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }

            // Card info
            Text(card.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack {
                Text(card.setCode.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if card.quantity > 1 {
                    Text("×\(card.quantity)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: Card.self, inMemory: true)
}
