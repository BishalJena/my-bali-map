// NavigationManager.swift
// MyBaliMap
//
// Orchestrates route computation and display.
// Bridges RoutingManager → MapView overlays and UI state.
//
// Features:
//   - Computes route via A* when user taps navigate icon
//   - Manages active route state (polyline, distance, ETA)
//   - Supports walking/driving mode toggle
//   - "Open in Apple Maps" deep link for real turn-by-turn
//
// Apple Frameworks: MapKit (MKMapItem), Observation (@Published)

import Foundation
import CoreLocation
import MapKit

@MainActor
final class NavigationManager: ObservableObject {

    // MARK: - Published State

    /// Active route polyline coordinates (nil when no route active).
    @Published var activeRoute: RouteResult?

    /// Whether a route is currently being computed.
    @Published var isComputingRoute: Bool = false

    /// Selected travel mode.
    @Published var selectedMode: TravelMode = .driving

    /// Formatted distance string (e.g. "3.2 km").
    @Published var formattedDistance: String?

    /// Formatted ETA string (e.g. "12 min driving").
    @Published var formattedETA: String?

    /// The place currently being navigated to.
    @Published var destinationPlace: Place?

    /// Error message if routing fails.
    @Published var routingError: String?

    // MARK: - Dependencies

    let routingManager = RoutingManager()

    // MARK: - Init

    init() {
        routingManager.loadGraph()
    }

    // MARK: - Route Computation

    /// Computes and activates a route from the user's location to a place.
    func navigateToPlace(_ place: Place, from userLocation: CLLocationCoordinate2D) {
        // #8: Clear any existing route first
        clearRoute()

        isComputingRoute = true
        routingError = nil
        destinationPlace = place

        let destination = CLLocationCoordinate2D(
            latitude: place.latitude,
            longitude: place.longitude
        )

        // Run routing (synchronous for small graphs — async wrapper if needed)
        let result = routingManager.findRoute(from: userLocation, to: destination)

        activeRoute = result
        formattedDistance = routingManager.formattedDistance(result.distanceMeters)
        formattedETA = routingManager.estimatedTime(
            distanceMeters: result.distanceMeters,
            mode: selectedMode
        )

        isComputingRoute = false

        if result.isStraightLine && routingManager.isGraphLoaded {
            routingError = "No road path found. Showing straight line."
        }
    }

    /// Updates ETA when travel mode changes.
    func updateMode(_ mode: TravelMode) {
        selectedMode = mode
        guard let route = activeRoute else { return }
        formattedETA = routingManager.estimatedTime(
            distanceMeters: route.distanceMeters,
            mode: mode
        )
    }

    /// Clears the active route and resets state.
    func clearRoute() {
        activeRoute = nil
        formattedDistance = nil
        formattedETA = nil
        destinationPlace = nil
        routingError = nil
    }

    /// Whether a route is currently active.
    var hasActiveRoute: Bool {
        activeRoute != nil
    }

    // MARK: - Apple Maps Fallback

    /// Opens Apple Maps with driving directions to the destination.
    func openInAppleMaps(destination: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: destination)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// Opens Apple Maps for the current destination place.
    func openCurrentRouteInAppleMaps() {
        guard let place = destinationPlace else { return }
        let coord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        openInAppleMaps(destination: coord, name: place.name.isEmpty ? "Saved Place" : place.name)
    }
}
