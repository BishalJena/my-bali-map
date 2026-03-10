// Constants.swift
// MyBaliMap
//
// App-wide constants: coordinates, file names, sizing, and defaults.

import Foundation
import CoreLocation

enum AppConstants {

    // MARK: - Bali Map Defaults

    /// Center of Bali (approximately Ubud area).
    static let baliCenter = CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)

    /// Default map zoom level for Bali overview.
    static let defaultZoomLevel: Double = 10.0

    /// Zoom level when centering on a specific location.
    static let focusZoomLevel: Double = 14.0

    // MARK: - Coordinate Formatting

    /// Coordinate display format: e.g. "-8.7370 S, 115.1757 E"
    static let coordinateDecimalPlaces = 4

    // MARK: - Note Constraints

    /// Maximum characters allowed in a place note.
    static let maxNoteLength = 20

    // MARK: - Persistence File Names

    static let placesFileName = "places.json"
    static let categoriesFileName = "categories.json"

    // MARK: - Bundle Resource Names

    static let baliTilesDirectory = "bali_tiles"
    static let nodesFileName = "nodes"       // nodes.json in bundle
    static let edgesFileName = "edges"       // edges.json in bundle

    // MARK: - UI Sizing

    /// Minimum touch target per Apple HIG.
    static let minTouchTarget: CGFloat = 44.0

    /// Toast display duration in seconds.
    static let toastDuration: TimeInterval = 3.0

    // MARK: - Map Tile Style

    /// Path to the MapLibre style JSON within the bundle.
    static let mapStyleFileName = "style"    // style.json in bali_tiles/
}
