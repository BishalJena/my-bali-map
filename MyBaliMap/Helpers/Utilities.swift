// Utilities.swift
// MyBaliMap
//
// Shared formatters, extensions, and helper functions.

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Coordinate Formatting

extension CLLocationCoordinate2D {
    /// Formats coordinates as "-8.7370 S, 115.1757 E".
    var formattedString: String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"
        let latValue = String(format: "%.\(AppConstants.coordinateDecimalPlaces)f", abs(latitude))
        let lonValue = String(format: "%.\(AppConstants.coordinateDecimalPlaces)f", abs(longitude))
        return "\(latValue) \(latDirection), \(lonValue) \(lonDirection)"
    }
}

// MARK: - Distance Formatting

extension CLLocation {
    /// Returns a human-readable distance string (e.g. "1.2 km" or "350 m").
    func formattedDistance(to other: CLLocation) -> String {
        let meters = distance(from: other)
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}

// MARK: - Color from Hex

extension Color {
    /// Creates a SwiftUI Color from a hex string like "#FF6B6B".
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date Formatting

extension Date {
    /// Short date string for display: "Mar 10, 2026".
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
