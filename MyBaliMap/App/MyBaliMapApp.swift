// MyBaliMapApp.swift
// MyBaliMap
//
// @main entry point for the My Bali Map app.
// Injects shared managers into the SwiftUI environment.
// Handles incoming files (AirDrop import) via onOpenURL.

import SwiftUI

@main
struct MyBaliMapApp: App {

    // MARK: - Shared State Objects

    @StateObject private var locationManager = LocationManager()
    @StateObject private var persistenceManager = PersistenceManager()
    @StateObject private var navigationManager = NavigationManager()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(persistenceManager)
                .environmentObject(navigationManager)
                .onOpenURL { url in
                    // AirDrop import handler
                    let airDrop = AirDropManager()
                    let _ = airDrop.handleIncomingFile(url, persistence: persistenceManager)
                }
        }
    }
}
