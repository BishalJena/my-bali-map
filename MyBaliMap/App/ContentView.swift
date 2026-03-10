// ContentView.swift
// MyBaliMap
//
// Root view with TabView: "Map" (Screen 1) and "Saved" (Screen 2).
// Includes a full-screen location permission gate:
//   - First launch: prompts for location access
//   - If denied: grays out entire app with a nudge to Settings
//   - App is fully functional only after location is granted
//
// Apple Components: TabView, ZStack, overlay, .disabled, .blur

import SwiftUI

struct ContentView: View {

    // MARK: - Environment

    @EnvironmentObject var locationManager: LocationManager

    // MARK: - State

    @State private var selectedTab: Tab = .map
    @State private var hasRequestedPermission: Bool = false

    enum Tab: Hashable {
        case map
        case saved
    }

    // MARK: - Computed

    /// True when we need to block the app (not yet determined, or denied).
    private var showPermissionGate: Bool {
        locationManager.authorizationStatus == .notDetermined ||
        locationManager.isLocationDenied
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main app content — disabled and blurred when permission gate is active
            TabView(selection: $selectedTab) {
                MapScreen()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .tag(Tab.map)

                SavedPlacesView()
                    .tabItem {
                        Label("Saved", systemImage: "bookmark.fill")
                    }
                    .tag(Tab.saved)
            }
            .disabled(showPermissionGate)
            .blur(radius: showPermissionGate ? 6 : 0)
            .animation(.easeInOut(duration: 0.3), value: showPermissionGate)

            // Permission gate overlay
            if showPermissionGate {
                locationPermissionGate
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Auto-request on first launch if not yet determined
            if locationManager.authorizationStatus == .notDetermined && !hasRequestedPermission {
                hasRequestedPermission = true
                locationManager.requestPermission()
            }
        }
    }

    // MARK: - Permission Gate

    /// Full-screen overlay blocking the app until location access is granted.
    private var locationPermissionGate: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)

                // Title
                Text("Location Access Required")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                // Message — differs based on state
                if locationManager.isLocationDenied {
                    // Denied state: nudge to Settings
                    deniedMessage
                } else {
                    // Not determined: waiting for system prompt
                    notDeterminedMessage
                }

                Spacer()
            }
            .padding(32)
        }
        .accessibilityLabel("Location permission required to use My Bali Map")
    }

    /// Message shown when permission hasn't been requested yet.
    private var notDeterminedMessage: some View {
        VStack(spacing: 16) {
            Text("My Bali Map needs your location to show where you are, save places at your current coordinates, and calculate distances.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                locationManager.requestPermission()
                hasRequestedPermission = true
            } label: {
                Text("Allow Location Access")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        }
    }

    /// Message shown when the user has denied location access.
    private var deniedMessage: some View {
        VStack(spacing: 16) {
            Text("Location access was denied. To use My Bali Map, please enable location access in Settings:")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Step-by-step instructions
            VStack(alignment: .leading, spacing: 10) {
                instructionRow(number: 1, text: "Open **Settings** on your iPhone")
                instructionRow(number: 2, text: "Scroll down and tap **My Bali Map**")
                instructionRow(number: 3, text: "Tap **Location** and select **While Using the App**")
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Open Settings button
            Button {
                locationManager.openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())

            Text("The app will unlock automatically once location is enabled.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    /// Single instruction row with a numbered circle.
    private func instructionRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview("Authorized") {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(PersistenceManager())
        .environmentObject(NavigationManager())
}
