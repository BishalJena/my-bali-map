// PlaceRowView.swift
// MyBaliMap
//
// A single row in the saved places list.
// Layout (from UI screenshot):
//   - Leading: Place Name (bold, .headline)
//   - Subtitle: Short Note (gray, .subheadline, single line truncated)
//   - Optional: distance from current location (e.g. "1.2 km")
//   - Trailing: map/directions icon button (SF Symbol "map.fill")
//
// Apple UI Components Used:
//   HStack, VStack, Text(.headline/.subheadline), Button, Image(systemName:)

import SwiftUI
import CoreLocation

struct PlaceRowView: View {

    // MARK: - Properties

    let place: Place
    let userLocation: CLLocation?
    let onNavigate: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            // TODO: Phase 5 — Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name.isEmpty ? "Unnamed Place" : place.name)
                    .font(.headline)

                // #15: Fallback when note is empty
                if place.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("No note")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    Text(place.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // TODO: Phase 5 — Distance from user
                if let distance = formattedDistance {
                    Text(distance)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Navigation / Directions button
            Button(action: onNavigate) {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(
                        minWidth: AppConstants.minTouchTarget,
                        minHeight: AppConstants.minTouchTarget
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Navigate to \(place.name)")
            .accessibilityHint("Opens route to this location")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var formattedDistance: String? {
        guard let userLocation else { return nil }
        let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
        return userLocation.formattedDistance(to: placeLocation)
    }
}

// MARK: - Preview

#Preview {
    List {
        PlaceRowView(
            place: .sample,
            userLocation: CLLocation(latitude: -8.5069, longitude: 115.2625),
            onNavigate: {}
        )
    }
}
