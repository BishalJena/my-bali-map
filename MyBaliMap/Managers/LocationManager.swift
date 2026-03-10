// LocationManager.swift
// MyBaliMap
//
// CoreLocation singleton — provides real-time GPS coordinates.
// GPS works in airplane mode (satellite receiver is passive).
//
// Features:
//   - Requests whenInUse authorization
//   - Continuous location updates (every ~60s via distanceFilter)
//   - Publishes live coordinate, formatted string, auth status
//   - Handles denied state with Settings deep-link
//   - Works fully offline (GPS only, no network assist)

import Foundation
import CoreLocation
import UIKit

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// Most recent CLLocation (includes altitude, accuracy, timestamp).
    @Published var userLocation: CLLocation?

    /// Most recent coordinate (convenience).
    @Published var userCoordinate: CLLocationCoordinate2D?

    /// Formatted string: e.g. "-8.7370 S, 115.1757 E"
    @Published var formattedCoordinate: String = "Locating…"

    /// Current authorization status.
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Human-readable error message, if any.
    @Published var locationError: String?

    /// Whether location is being actively tracked.
    @Published var isTracking: Bool = false

    // MARK: - Computed

    /// True when permission has been denied or restricted.
    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// True when permission is granted (either always or whenInUse).
    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Private

    private let manager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // Update when user moves ≥ 10 meters — saves battery while still
        // giving "real-time" feel. For truly continuous updates, set to 0.
        manager.distanceFilter = 10

        // Allow background indicator (shows blue bar) — optional
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true

        // Read current auth status on init
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    /// Request location permission (must call before startUpdating).
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Begin continuous GPS updates.
    func startUpdating() {
        guard isLocationAuthorized else {
            requestPermission()
            return
        }
        manager.startUpdatingLocation()
        isTracking = true
    }

    /// Stop GPS updates to conserve battery.
    func stopUpdating() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

    /// Request a single location fix (useful for "Use My Location" button).
    func requestCurrentLocation() {
        guard isLocationAuthorized else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    /// Returns most recent coordinate, or nil if unavailable.
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return userCoordinate
    }

    /// Opens iOS Settings so user can enable location for this app.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.userLocation = location
            self.userCoordinate = location.coordinate
            self.formattedCoordinate = location.coordinate.formattedString
            self.locationError = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            self.authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                // Auto-start tracking once authorized
                self.startUpdating()
            case .denied, .restricted:
                self.locationError = "Location access denied. Enable in Settings."
                self.isTracking = false
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            // Don't overwrite coordinate on transient errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Location access denied."
                case .locationUnknown:
                    // Transient — GPS still acquiring. Don't show error.
                    break
                default:
                    self.locationError = "Location error: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = error.localizedDescription
            }
        }
    }
}
