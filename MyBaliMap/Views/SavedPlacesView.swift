// SavedPlacesView.swift
// MyBaliMap
//
// Screen 2 — "Saved"
// Features:
//   - NavigationStack with large title "Saved" + "Edit" button
//   - List with DisclosureGroup per category
//   - Edit mode: multi-select checkmarks on rows + bulk "Delete" toolbar button
//   - Normal mode: row tap → edit sheet, map icon → navigate, context menu → share/delete
//
// Apple Components:
//   NavigationStack, List, DisclosureGroup, EditButton, EditMode,
//   ForEach, ContentUnavailableView, .toolbar

import SwiftUI
import CoreLocation

struct SavedPlacesView: View {

    // MARK: - Environment

    @EnvironmentObject var persistenceManager: PersistenceManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationManager: NavigationManager

    // MARK: - State

    @State private var expandedCategories: Set<UUID> = []
    @State private var selectedPlace: Place?
    @State private var showEditSheet: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var showDeleteConfirmation: Bool = false  // #5
    @State private var showGPSAlert: Bool = false  // #7

    /// IDs of places selected for bulk deletion in edit mode.
    @State private var selectedForDeletion: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if categoriesWithPlaces.isEmpty {
                    emptyState
                } else {
                    placesList
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    editDoneButton
                }
                // Bulk delete button — bottom toolbar, only in edit mode
                if editMode == .active {
                    ToolbarItem(placement: .bottomBar) {
                        deleteSelectedButton
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showEditSheet) {
                if let place = selectedPlace {
                    PlaceEditSheet(
                        place: place,
                        categories: persistenceManager.categories,
                        onSave: { updated in
                            if let idx = persistenceManager.places.firstIndex(where: { $0.id == updated.id }) {
                                persistenceManager.places[idx] = updated
                                persistenceManager.savePlaces(persistenceManager.places)
                            }
                        },
                        onDelete: {
                            persistenceManager.deletePlace(place)
                            showEditSheet = false
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .onChange(of: editMode) { _, newMode in
                if newMode == .active {
                    // Auto-expand all categories so user can see all places
                    for group in categoriesWithPlaces {
                        expandedCategories.insert(group.category.id)
                    }
                } else {
                    // Clear selection when exiting edit mode
                    selectedForDeletion.removeAll()
                }
            }
            // #5: Confirmation dialog before bulk delete
            .confirmationDialog(
                "Delete \(selectedForDeletion.count) place\(selectedForDeletion.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedPlaces()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action can't be undone.")
            }
            // #7: GPS not ready alert
            .alert("GPS Not Ready", isPresented: $showGPSAlert) {
                Button("OK") { }
            } message: {
                Text("Your location hasn't been acquired yet. Please wait a moment and try again.")
            }
        }
    }

    // MARK: - Edit / Done Button

    /// Custom edit/done toggle button (replaces EditButton for more control).
    private var editDoneButton: some View {
        Button {
            withAnimation {
                if editMode == .active {
                    editMode = .inactive
                } else {
                    editMode = .active
                }
            }
        } label: {
            Text(editMode == .active ? "Done" : "Edit")
        }
        .disabled(categoriesWithPlaces.isEmpty)
    }

    // MARK: - Delete Selected Button

    /// Bottom toolbar button showing count and executing bulk delete.
    private var deleteSelectedButton: some View {
        Button(role: .destructive) {
            // #5: Show confirmation instead of deleting immediately
            showDeleteConfirmation = true
        } label: {
            if selectedForDeletion.isEmpty {
                Text("Select places to delete")
                    .foregroundStyle(.secondary)
            } else {
                Text("Delete \(selectedForDeletion.count) Place\(selectedForDeletion.count == 1 ? "" : "s")")
                    .fontWeight(.semibold)
            }
        }
        .disabled(selectedForDeletion.isEmpty)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Places List

    private var placesList: some View {
        List {
            ForEach(categoriesWithPlaces, id: \.category.id) { group in
                DisclosureGroup(
                    isExpanded: binding(for: group.category.id)
                ) {
                    ForEach(group.places) { place in
                        if editMode == .active {
                            // Edit mode: selectable rows with checkmarks
                            editModeRow(for: place)
                        } else {
                            // Normal mode: full interactive row
                            normalModeRow(for: place)
                        }
                    }
                } label: {
                    categoryHeader(for: group)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Normal Mode Row

    /// Interactive row: tap → edit sheet, map icon → navigate, long press → context menu.
    private func normalModeRow(for place: Place) -> some View {
        PlaceRowView(
            place: place,
            userLocation: locationManager.userLocation,
            onNavigate: {
                navigateToPlace(place)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlace = place
            showEditSheet = true
        }
        .contextMenu {
            Button {
                AirDropManager().sharePlace(place)
            } label: {
                Label("Share via AirDrop", systemImage: "square.and.arrow.up")
            }
            Button {
                navigateToPlace(place)
            } label: {
                Label("Navigate", systemImage: "map.fill")
            }
            Button(role: .destructive) {
                persistenceManager.deletePlace(place)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Edit Mode Row

    /// Selectable row with leading checkmark circle for bulk deletion.
    private func editModeRow(for place: Place) -> some View {
        let isSelected = selectedForDeletion.contains(place.id)

        return HStack(spacing: 14) {
            // Selection checkmark circle
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            // Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name.isEmpty ? "Unnamed Place" : place.name)
                    .font(.headline)

                // #11: Fallback text when note is empty
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
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedForDeletion.remove(place.id)
                } else {
                    selectedForDeletion.insert(place.id)
                }
            }
        }
        .accessibilityLabel("\(place.name.isEmpty ? "Unnamed Place" : place.name), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") for deletion")
    }

    // MARK: - Category Header

    /// Category label row with icon.
    private func categoryHeader(for group: CategoryGroup) -> some View {
        HStack {
            Text(group.category.name)
                .font(.headline)

            Spacer()

            // Category icon
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Saved Places", systemImage: "mappin.slash")
        } description: {
            Text("Places you save on the Map tab will appear here.")
        }
    }

    // MARK: - Grouped Data

    /// Groups places by their category, filtering out categories with no places.
    private var categoriesWithPlaces: [CategoryGroup] {
        persistenceManager.categories.compactMap { category in
            let places = persistenceManager.places.filter { $0.categoryId == category.id }
            guard !places.isEmpty else { return nil }
            return CategoryGroup(category: category, places: places)
        }
    }

    // MARK: - Helpers

    /// Binding for DisclosureGroup expansion state.
    private func binding(for categoryId: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(categoryId) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(categoryId)
                } else {
                    expandedCategories.remove(categoryId)
                }
            }
        )
    }

    /// Deletes all places in the selection set and exits edit mode.
    private func deleteSelectedPlaces() {
        let idsToDelete = selectedForDeletion

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        for id in idsToDelete {
            if let place = persistenceManager.places.first(where: { $0.id == id }) {
                persistenceManager.deletePlace(place)
            }
        }

        selectedForDeletion.removeAll()

        // Exit edit mode if list is now empty
        if categoriesWithPlaces.isEmpty {
            withAnimation {
                editMode = .inactive
            }
        }
    }

    /// Triggers route computation.
    private func navigateToPlace(_ place: Place) {
        // #7: Show alert if GPS not ready
        guard let userCoord = locationManager.userCoordinate else {
            showGPSAlert = true
            locationManager.requestCurrentLocation()
            return
        }
        navigationManager.navigateToPlace(place, from: userCoord)
    }
}

// MARK: - Category Group Model

struct CategoryGroup {
    let category: Category
    let places: [Place]
}

// MARK: - Place Edit Sheet

struct PlaceEditSheet: View {

    @State var place: Place
    let categories: [Category]
    let onSave: (Place) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Place Name", text: $place.name)

                    HStack {
                        TextField("Note", text: $place.note)
                            .onChange(of: place.note) { _, newValue in
                                if newValue.count > AppConstants.maxNoteLength {
                                    place.note = String(newValue.prefix(AppConstants.maxNoteLength))
                                }
                            }
                        Text("\(place.note.count)/\(AppConstants.maxNoteLength)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }

                Section("Category") {
                    ForEach(categories) { category in
                        HStack {
                            Text(category.name)
                            Spacer()
                            if place.categoryId == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            place.categoryId = category.id
                        }
                    }
                }

                Section("Location") {
                    let coord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    Text(coord.formattedString)
                        .foregroundStyle(.secondary)

                    Text("Saved \(place.createdAt.shortFormatted)")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Delete Place", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // #10: Disable Save when note is empty
                    Button("Save") {
                        onSave(place)
                        dismiss()
                    }
                    .disabled(place.note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SavedPlacesView()
        .environmentObject(PersistenceManager())
        .environmentObject(LocationManager())
        .environmentObject(NavigationManager())
}
