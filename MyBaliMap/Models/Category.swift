// Category.swift
// MyBaliMap
//
// Data model for place categories (e.g. Eateries, Shopping, Viewpoints).
// Fully implemented — Codable, Identifiable, with default seeds.

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

// MARK: - Default Categories

extension Category {
    /// Pre-seeded category: Eateries
    static let defaultEateries = Category(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
        name: "Eateries",
        iconName: "fork.knife",
        colorHex: "#FF6B6B"
    )

    /// Pre-seeded category: Shopping
    static let defaultShopping = Category(
        id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!,
        name: "Shopping",
        iconName: "bag.fill",
        colorHex: "#4ECDC4"
    )

    /// Pre-seeded category: Viewpoints
    static let defaultViewpoints = Category(
        id: UUID(uuidString: "C3D4E5F6-A7B8-9012-CDEF-123456789012")!,
        name: "Viewpoints",
        iconName: "binoculars.fill",
        colorHex: "#45B7D1"
    )

    /// All default categories shipped with the app.
    static let defaults: [Category] = [
        defaultEateries,
        defaultShopping,
        defaultViewpoints
    ]
}
