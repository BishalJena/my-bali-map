// MapScreen.swift
// MyBaliMap
//
// Screen 1 — "My Bali Map"
// Layout matches the UI screenshot:
//   - NavigationStack with large bold title "My Bali Map"
//   - MapView in rounded container with floating "Use My Location" button
//   - Live coordinate text below map (updates real-time via GPS, works offline)
//   - "Note" section header
//   - Grouped form card: "Name of Place" + "Note under 20 characters" TextFields
//   - Horizontal scrollable category chips with leading "+" button
//   - Full-width "Add Location" capsule button
//
// Apple Components:
//   NavigationStack, Map w/ MapCameraPosition, TextField, ScrollView(.horizontal),
//   Button(.borderedProminent), Capsule, Section headers

import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {

    // MARK: - Environment

    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var persistenceManager: PersistenceManager
    @EnvironmentObject var navigationManager: NavigationManager

    // MARK: - Map State

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: AppConstants.baliCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )

    // MARK: - Form State

    @State private var placeName: String = ""
    @State private var placeNote: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var showAddCategory: Bool = false
    @State private var isSaving: Bool = false  // Debounce guard (#1)

    // MARK: - Toast State

    @State private var showSavedToast: Bool = false
    @State private var toastPlaceId: UUID?  // Tracks which place the toast is for (#3)
    @State private var toastDismissTask: Task<Void, Never>?  // Cancellable timer (#12)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mapSection
                    coordinateLabel
                    formCard
                    categoryChips
                    addLocationButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)  // #4: Dismiss keyboard on scroll
            .navigationTitle("My Bali Map")
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    toastView
                }
            }
        }
    }

    // MARK: - Map Section

    /// Map with floating "Use My Location" button (bottom-right) and route overlay.
    private var mapSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                MapView(
                    cameraPosition: $cameraPosition,
                    showsUserLocation: locationManager.isLocationAuthorized,
                    annotations: savedPlaceAnnotations,
                    routeCoordinates: navigationManager.activeRoute?.coordinates
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Floating "Use My Location" button
                Button {
                    centerOnUserLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .padding(12)
                .accessibilityLabel("Use My Location")
                .accessibilityHint("Centers the map on your current location")
            }

            // Route info bar (shown when a route is active)
            if navigationManager.hasActiveRoute {
                routeInfoBar
            }
        }
    }

    /// Route info bar showing distance, ETA, mode toggle, and Apple Maps button.
    private var routeInfoBar: some View {
        HStack(spacing: 12) {
            // Distance
            if let distance = navigationManager.formattedDistance {
                Label(distance, systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.medium))
            }

            // ETA
            if let eta = navigationManager.formattedETA {
                Text(eta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mode toggle
            Menu {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Button {
                        navigationManager.updateMode(mode)
                    } label: {
                        Label(mode.rawValue, systemImage: mode.iconName)
                    }
                }
            } label: {
                Image(systemName: navigationManager.selectedMode.iconName)
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
            }

            // Open in Apple Maps
            Button {
                navigationManager.openCurrentRouteInAppleMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Open in Apple Maps")

            // Close route
            Button {
                navigationManager.clearRoute()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Close route")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Live Coordinate Display

    /// Shows real-time GPS coordinates, updated continuously.
    /// GPS works in airplane mode — satellite receiver is passive.
    private var coordinateLabel: some View {
        Group {
            if locationManager.isLocationDenied {
                // Denied state: show message + Settings button
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundStyle(.secondary)
                    Text("Location access denied")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Settings") {
                        locationManager.openSettings()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            } else {
                // Live coordinate text
                Text(locationManager.formattedCoordinate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: locationManager.formattedCoordinate)
                    .accessibilityLabel("Current coordinates: \(locationManager.formattedCoordinate)")
            }
        }
    }

    // MARK: - Form Card

    /// Grouped form with place name and note text fields.
    private var formCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.headline)

            VStack(spacing: 0) {
                // Place Name field
                TextField("Name of Place", text: $placeName)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .accessibilityLabel("Place name")
                    .accessibilityHint("Optional. Enter a name for the location.")

                Divider()
                    .padding(.leading, 16)

                // Note field with character counter
                HStack {
                    TextField("Note under 20 characters", text: $placeNote)
                        .textFieldStyle(.plain)
                        .onChange(of: placeNote) { _, newValue in
                            // Enforce 20-char limit
                            if newValue.count > AppConstants.maxNoteLength {
                                placeNote = String(newValue.prefix(AppConstants.maxNoteLength))
                            }
                        }
                        .accessibilityLabel("Short note")
                        .accessibilityHint("Required. Maximum 20 characters.")

                    Text("\(placeNote.count)/\(AppConstants.maxNoteLength)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Category Chips

    /// Horizontal scrollable chip row with leading "+" button.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Leading "+" chip to add new category
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(
                            minWidth: AppConstants.minTouchTarget,
                            minHeight: AppConstants.minTouchTarget
                        )
                }
                .accessibilityLabel("Add new category")
                .accessibilityHint("Opens a sheet to create a custom category")

                // Category chips
                ForEach(persistenceManager.categories) { category in
                    CategoryChipView(
                        category: category,
                        isSelected: selectedCategoryId == category.id,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedCategoryId == category.id {
                                    selectedCategoryId = nil  // Deselect
                                } else {
                                    selectedCategoryId = category.id
                                }
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(
                existingCategories: persistenceManager.categories
            ) { newCategory in
                persistenceManager.addCategory(newCategory)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Add Location Button

    /// Full-width capsule button. Disabled until note is non-empty, category is selected,
    /// GPS is available, and not currently saving (debounce).
    private var addLocationButton: some View {
        let hasNote = !placeNote.trimmingCharacters(in: .whitespaces).isEmpty
        let hasCategory = selectedCategoryId != nil
        let hasGPS = locationManager.userCoordinate != nil
        let isEnabled = hasNote && hasCategory && hasGPS && !isSaving

        return VStack(spacing: 6) {
            // #9: Warning when GPS not available
            if !hasGPS && hasNote && hasCategory {
                Label("Waiting for GPS fix…", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                savePlace()
            } label: {
                Text("Add Location")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isEnabled ? .blue : Color(.systemGray4))
            .disabled(!isEnabled)
            .clipShape(Capsule())
            .accessibilityLabel("Add Location")
            .accessibilityHint(
                !hasGPS
                    ? "Waiting for GPS location"
                    : isEnabled
                        ? "Saves this place with the current GPS coordinates"
                        : "Enter a note and select a category first"
            )
        }
    }

    // MARK: - Toast View

    /// Confirmation toast with undo action, shown for ~3 seconds.
    private var toastView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Location saved")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Undo") {
                undoSave()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Annotations

    /// Annotations for all saved places.
    private var savedPlaceAnnotations: [PlaceAnnotation] {
        persistenceManager.places.map { PlaceAnnotation(from: $0) }
    }

    // MARK: - Actions

    /// Centers the map on the user's current GPS location.
    private func centerOnUserLocation() {
        if let coordinate = locationManager.userCoordinate {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            }
        } else {
            // No location yet — request it
            locationManager.requestCurrentLocation()
        }
    }

    /// Saves the current form data as a new Place.
    private func savePlace() {
        // #1: Debounce — prevent double-tap duplicates
        guard !isSaving else { return }
        guard let categoryId = selectedCategoryId else { return }
        guard let coordinate = locationManager.userCoordinate else { return }  // #9: Require GPS

        isSaving = true

        let place = Place(
            name: placeName,
            note: placeNote,
            categoryId: categoryId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        persistenceManager.addPlace(place)

        // #3: Track specifically which place this toast is for
        toastPlaceId = place.id

        // Clear form
        placeName = ""
        placeNote = ""
        selectedCategoryId = nil

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Center map on saved pin
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }

        // Show toast
        withAnimation(.spring(duration: 0.4)) {
            showSavedToast = true
        }

        // #12: Cancellable toast timer — cancel previous if still running
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(AppConstants.toastDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedToast = false
                isSaving = false
            }
        }
    }

    /// Undoes the last save — deletes the specific place this toast is for (#3).
    private func undoSave() {
        if let placeId = toastPlaceId,
           let place = persistenceManager.places.first(where: { $0.id == placeId }) {
            persistenceManager.deletePlace(place)
        }
        toastPlaceId = nil
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            showSavedToast = false
            isSaving = false
        }
    }
}

// MARK: - Preview

#Preview {
    MapScreen()
        .environmentObject(LocationManager())
        .environmentObject(PersistenceManager())
        .environmentObject(NavigationManager())
}

// MARK: - Add Category Sheet

/// Modal sheet to create a new custom category.
struct AddCategorySheet: View {
    @State private var categoryName: String = ""
    @State private var selectedIcon: String = "mappin"

    let existingCategories: [Category]  // #6: For duplicate check
    let onSave: (Category) -> Void
    @Environment(\.dismiss) private var dismiss

    private let availableIcons = [
        "mappin", "fork.knife", "bag.fill", "binoculars.fill",
        "cup.and.saucer.fill", "bed.double.fill", "figure.surfing",
        "music.note", "heart.fill", "star.fill", "leaf.fill",
        "camera.fill", "paintpalette.fill", "cart.fill"
    ]

    // #6: Check if name already exists (case-insensitive)
    private var isDuplicate: Bool {
        let trimmed = categoryName.trimmingCharacters(in: .whitespaces).lowercased()
        return existingCategories.contains { $0.name.lowercased() == trimmed }
    }

    private var nameIsEmpty: Bool {
        categoryName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("Enter name", text: $categoryName)

                    // #6: Duplicate warning
                    if isDuplicate {
                        Label("A category with this name already exists.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let category = Category(
                            name: categoryName.trimmingCharacters(in: .whitespaces),
                            iconName: selectedIcon
                        )
                        onSave(category)
                        dismiss()
                    }
                    .disabled(nameIsEmpty || isDuplicate)  // #6
                }
            }
        }
    }
}
