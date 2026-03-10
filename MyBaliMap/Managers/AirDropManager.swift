// AirDropManager.swift
// MyBaliMap
//
// Handles sharing places via AirDrop and importing received JSON files.
//
// Export: Encodes Place → JSON file → UIActivityViewController (AirDrop, Messages, etc.)
// Import: Reads JSON file → validates → inserts into PersistenceManager
//
// Apple Frameworks: UIKit (UIActivityViewController), Foundation (JSONEncoder/Decoder)

import Foundation
import UIKit

final class AirDropManager {

    // MARK: - Export

    /// Creates a temporary JSON file for a place and returns its URL.
    /// The file is named "{place-name}-{short-id}.baliplace.json".
    func exportPlace(_ place: Place) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(place)

            let safeName = place.name.isEmpty
                ? "place"
                : place.name
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                    .prefix(20)

            let shortId = place.id.uuidString.prefix(8).lowercased()
            let fileName = "\(safeName)-\(shortId).baliplace.json"

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("⚠️ AirDropManager: Failed to export place: \(error.localizedDescription)")
            return nil
        }
    }

    /// Presents the system share sheet for a place.
    /// Uses UIActivityViewController, which supports AirDrop, Messages, Mail, etc.
    @MainActor
    func sharePlace(_ place: Place) {
        guard let fileURL = exportPlace(place) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )

        // Exclude irrelevant activities
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo
        ]

        // Present from root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else { return }

        // Handle iPad popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        rootVC.present(activityVC, animated: true)
    }

    // MARK: - Import

    /// Validates and parses a JSON file URL into a Place.
    func importPlace(from url: URL) -> Place? {
        do {
            // Start accessing security-scoped resource if needed
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var place = try decoder.decode(Place.self, from: data)

            // Validate and sanitize
            place.note = String(place.note.prefix(Place.maxNoteLength))

            // Validate coordinate range (Bali area: roughly -9.5 to -8.0 lat, 114.5 to 116.0 lon)
            guard place.latitude >= -90 && place.latitude <= 90,
                  place.longitude >= -180 && place.longitude <= 180
            else {
                print("⚠️ AirDropManager: Invalid coordinates in imported place.")
                return nil
            }

            return place
        } catch {
            print("⚠️ AirDropManager: Failed to import place: \(error.localizedDescription)")
            return nil
        }
    }

    /// Handles an incoming file URL (e.g. from AirDrop via onOpenURL).
    /// Returns true if the place was successfully imported.
    @MainActor
    func handleIncomingFile(
        _ url: URL,
        persistence: PersistenceManager
    ) -> Bool {
        guard let place = importPlace(from: url) else { return false }

        // Check for duplicates by ID
        if persistence.places.contains(where: { $0.id == place.id }) {
            print("ℹ️ AirDropManager: Place already exists (id: \(place.id)). Skipping.")
            return false
        }

        // Ensure the place's category exists; if not, add a generic one
        if !persistence.categories.contains(where: { $0.id == place.categoryId }) {
            let genericCategory = Category(
                id: place.categoryId,
                name: "Imported",
                iconName: "square.and.arrow.down"
            )
            persistence.addCategory(genericCategory)
        }

        persistence.addPlace(place)
        print("✅ AirDropManager: Imported place '\(place.name)'.")
        return true
    }

    // MARK: - Batch Export

    /// Exports multiple places as a single JSON array file.
    func exportPlaces(_ places: [Place]) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(places)

            let fileName = "my-bali-places-\(places.count).json"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("⚠️ AirDropManager: Failed to export places batch: \(error.localizedDescription)")
            return nil
        }
    }
}
