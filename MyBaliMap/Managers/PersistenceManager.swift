// PersistenceManager.swift
// MyBaliMap
//
// JSON-based local persistence for places and categories.
// Reads/writes to Documents directory: places.json, categories.json.
// Conforms to PersistenceProtocol for future CoreData migration.
//
// Apple Frameworks: Foundation (FileManager, JSONEncoder/Decoder)

import Foundation

// MARK: - Persistence Protocol

/// Abstraction layer for persistence — swap JSON for CoreData later.
protocol PersistenceProtocol {
    func loadPlaces() -> [Place]
    func savePlaces(_ places: [Place])
    func addPlace(_ place: Place)
    func deletePlace(_ place: Place)

    func loadCategories() -> [Category]
    func saveCategories(_ categories: [Category])
    func addCategory(_ category: Category)
    func deleteCategory(_ category: Category)
}

// MARK: - JSON Persistence Manager

@MainActor
final class PersistenceManager: ObservableObject, PersistenceProtocol {

    // MARK: - Published State

    @Published var places: [Place] = []
    @Published var categories: [Category] = []

    // MARK: - File URLs

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var placesFileURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.placesFileName)
    }

    private var categoriesFileURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.categoriesFileName)
    }

    // MARK: - Init

    init() {
        // TODO: Phase 3 — Load data on init
        categories = loadCategories()
        places = loadPlaces()
    }

    // MARK: - Places

    func loadPlaces() -> [Place] {
        // TODO: Phase 3 — Implement JSON decoding
        return load(from: placesFileURL) ?? []
    }

    func savePlaces(_ places: [Place]) {
        // TODO: Phase 3 — Implement JSON encoding
        save(places, to: placesFileURL)
        self.places = places
    }

    func addPlace(_ place: Place) {
        // TODO: Phase 3 — Implement
        places.append(place)
        savePlaces(places)
    }

    func deletePlace(_ place: Place) {
        // TODO: Phase 3 — Implement
        places.removeAll { $0.id == place.id }
        savePlaces(places)
    }

    // MARK: - Categories

    func loadCategories() -> [Category] {
        // TODO: Phase 3 — Implement; seed defaults if file missing
        let loaded: [Category]? = load(from: categoriesFileURL)
        if let loaded, !loaded.isEmpty {
            return loaded
        }
        // Seed with defaults
        let defaults = Category.defaults
        saveCategories(defaults)
        return defaults
    }

    func saveCategories(_ categories: [Category]) {
        // TODO: Phase 3 — Implement
        save(categories, to: categoriesFileURL)
        self.categories = categories
    }

    func addCategory(_ category: Category) {
        // TODO: Phase 3 — Implement
        categories.append(category)
        saveCategories(categories)
    }

    func deleteCategory(_ category: Category) {
        // #2: Cascade-delete all places in this category to prevent orphans
        places.removeAll { $0.categoryId == category.id }
        savePlaces(places)

        categories.removeAll { $0.id == category.id }
        saveCategories(categories)
    }

    // MARK: - Undo Support

    /// Removes the most recently added place (for undo toast).
    func undoLastAdd() -> Place? {
        // TODO: Phase 4 — Implement
        guard let last = places.last else { return nil }
        deletePlace(last)
        return last
    }

    // MARK: - Generic JSON Helpers

    private func load<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ PersistenceManager: Failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func save<T: Encodable>(_ items: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ PersistenceManager: Failed to save \(url.lastPathComponent): \(error)")
        }
    }
}
