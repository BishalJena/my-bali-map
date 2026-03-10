// MapView.swift
// MyBaliMap
//
// SwiftUI map component using Apple MapKit as development placeholder.
// Will be swapped to MapLibre UIViewRepresentable when offline tiles are bundled.
//
// Current behavior:
//   - Renders Apple Maps centered on Bali
//   - Shows user location marker when authorized
//   - Supports pin annotations for saved places
//   - Pan & pinch-to-zoom gestures (native)
//   - Route polyline overlay
//
// Apple Components: Map, MapCameraPosition, Annotation, MapPolyline

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {

    // MARK: - Properties

    /// Camera position binding — controls center and zoom.
    @Binding var cameraPosition: MapCameraPosition

    /// Whether to show the user's blue dot.
    var showsUserLocation: Bool = false

    /// Saved place pins to display.
    var annotations: [PlaceAnnotation] = []

    /// Route polyline coordinates (if a route is active).
    var routeCoordinates: [CLLocationCoordinate2D]? = nil

    /// Called when user taps on the map (returns tapped coordinate).
    var onMapTap: ((CLLocationCoordinate2D) -> Void)? = nil

    // MARK: - Body

    var body: some View {
        Map(position: $cameraPosition, interactionModes: .all) {

            // User location blue dot
            if showsUserLocation {
                UserAnnotation()
            }

            // Saved place pins
            ForEach(annotations) { annotation in
                Annotation(
                    annotation.title,
                    coordinate: annotation.coordinate
                ) {
                    PlacePinView(title: annotation.title)
                }
            }

            // Route polyline overlay
            if let routeCoordinates, routeCoordinates.count >= 2 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
}

// MARK: - Place Pin View (custom annotation content)

/// Small pin marker for saved places on the map.
private struct PlacePinView: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundStyle(.red)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .offset(y: -3)
        }
        .accessibilityLabel("Pin for \(title)")
    }
}

// MARK: - Place Annotation Model

/// Lightweight annotation model for map pins.
struct PlaceAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?

    init(from place: Place) {
        self.id = place.id
        self.coordinate = CLLocationCoordinate2D(
            latitude: place.latitude,
            longitude: place.longitude
        )
        self.title = place.name.isEmpty ? "Saved Place" : place.name
        self.subtitle = place.note
    }

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        title: String,
        subtitle: String? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Preview

#Preview {
    MapView(
        cameraPosition: .constant(
            .region(MKCoordinateRegion(
                center: AppConstants.baliCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        ),
        showsUserLocation: true,
        annotations: [
            PlaceAnnotation(
                coordinate: AppConstants.baliCenter,
                title: "Ubud"
            )
        ]
    )
    .frame(height: 300)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding()
}
