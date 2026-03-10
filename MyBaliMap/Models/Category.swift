// Category.swift
// MyBaliMap
//
// Data model for place categories (e.g. Shop, Views, Food, Turf, Pubs).
// Fully implemented — Codable, Identifiable, with default seeds.
// Defaults match the UI screenshot's chip row.

import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var iconName: String?   // Optional SF Symbol name
    var colorHex: String?   // Optional hex color string

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }
}

// MARK: - Default Categories (matches screenshot chip row)

extension Category {
    /// Pre-seeded category: Shop (Shopping)
    static let defaultShopping = Category(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
        name: "Shop",
        iconName: "bag.fill",
        colorHex: "#4ECDC4"
    )

    /// Pre-seeded category: Views (Viewpoints)
    static let defaultViewpoints = Category(
        id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!,
        name: "Views",
        iconName: "binoculars.fill",
        colorHex: "#45B7D1"
    )

    /// Pre-seeded category: Food (Eateries)
    static let defaultEateries = Category(
        id: UUID(uuidString: "C3D4E5F6-A7B8-9012-CDEF-123456789012")!,
        name: "Food",
        iconName: "fork.knife",
        colorHex: "#FF6B6B"
    )

    /// Pre-seeded category: Turf (Activities / Outdoors)
    static let defaultTurf = Category(
        id: UUID(uuidString: "D4E5F6A7-B8C9-0123-DEFA-234567890123")!,
        name: "Turf",
        iconName: "figure.surfing",
        colorHex: "#96CEB4"
    )

    /// Pre-seeded category: Pubs (Nightlife)
    static let defaultPubs = Category(
        id: UUID(uuidString: "E5F6A7B8-C9D0-1234-EFAB-345678901234")!,
        name: "Pubs",
        iconName: "cup.and.saucer.fill",
        colorHex: "#DDA0DD"
    )

    /// All default categories shipped with the app (matches screenshot order).
    static let defaults: [Category] = [
        defaultShopping,
        defaultViewpoints,
        defaultEateries,
        defaultTurf,
        defaultPubs
    ]
}
