// Place.swift
// MyBaliMap
//
// Data model for a saved location pin.
// Fully implemented — Codable, Identifiable, with validation.

import Foundation

struct Place: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var note: String          // ≤ 20 characters
    var categoryId: UUID
    var latitude: Double
    var longitude: Double
    var createdAt: Date

    /// Maximum allowed length for the note field.
    static let maxNoteLength = 20

    /// Creates a new Place, truncating `note` to 20 characters if needed.
    init(
        id: UUID = UUID(),
        name: String = "",
        note: String,
        categoryId: UUID,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.note = String(note.prefix(Self.maxNoteLength))
        self.categoryId = categoryId
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    /// Validates that required fields are present for saving.
    var isValid: Bool {
        !note.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Sample Data (for previews and testing)

extension Place {
    static let sample = Place(
        name: "Steak House",
        note: "Best Steak < 200K",
        categoryId: Category.defaultEateries.id,
        latitude: -8.7370,
        longitude: 115.1757
    )

    static let samples: [Place] = [
        Place(
            name: "Steak House",
            note: "Best Steak < 200K",
            categoryId: Category.defaultEateries.id,
            latitude: -8.7370,
            longitude: 115.1757
        ),
        Place(
            name: "Aunt's Coffee",
            note: "9/10 coffee beans",
            categoryId: Category.defaultEateries.id,
            latitude: -8.5069,
            longitude: 115.2625
        ),
        Place(
            name: "Warung",
            note: "Good Nasi Goreng",
            categoryId: Category.defaultEateries.id,
            latitude: -8.5100,
            longitude: 115.2640
        ),
        Place(
            name: "Ayam Guling",
            note: "Delicious Marination",
            categoryId: Category.defaultEateries.id,
            latitude: -8.5200,
            longitude: 115.2700
        )
    ]
}
