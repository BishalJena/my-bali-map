# My Bali Map — iOS App

An offline-first SwiftUI iOS app for saving and navigating to places in Bali.

## Requirements

- **Xcode 15+** (Swift 5.9+)
- **iOS 17+** deployment target
- **MapLibre Native iOS** — offline vector tile renderer

## Xcode Setup

### 1. Create a New Xcode Project

1. Open Xcode → **New Project** → **App**
2. Product Name: `MyBaliMap`
3. Team: your dev team
4. Organization Identifier: e.g. `com.yourname`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Target: **iOS 17.0+**

### 2. Add Source Files

1. Delete the auto-generated `ContentView.swift`
2. Drag the `MyBaliMap/` folder into the project navigator (select **Create groups**, ensure target is checked)
3. Drag the `Resources/` folder into the project (select **Create folder references** for `bali_tiles/`)

### 3. Add MapLibre via Swift Package Manager

1. File → **Add Package Dependencies**
2. Enter URL: `https://github.com/maplibre/maplibre-gl-native-distribution`
3. Set version rule: **Up to Next Major** from `6.0.0`
4. Add `MapLibre` to the `MyBaliMap` target

### 4. Configure Info.plist

Add the following keys:

| Key | Value |
|-----|-------|
| `NSLocationWhenInUseUsageDescription` | "My Bali Map uses your location to show where you are and calculate distances to saved places." |
| `CFBundleDocumentTypes` | Configure for `.json` import (AirDrop) |

### 5. Bundled Assets

Place these in `Resources/`:

| File/Folder | Description |
|-------------|-------------|
| `bali_tiles/` | MapLibre vector tiles (MBTiles unpacked or directory with `style.json`) |
| `nodes.json` | Road graph nodes: `[{ "id": Int, "lat": Double, "lon": Double }]` |
| `edges.json` | Road graph edges: `[{ "from": Int, "to": Int, "distance": Double }]` |
| `default_categories.json` | Seed categories (Eateries, Shopping, Viewpoints) |

### 6. Simulator Testing

To test with Bali coordinates in Simulator:

1. Run the app in Simulator
2. **Features → Location → Custom Location**
3. Enter: Latitude `−8.5069`, Longitude `115.2625` (Ubud)

Or create a `.gpx` file:

```xml
<?xml version="1.0"?>
<gpx version="1.1">
  <wpt lat="-8.5069" lon="115.2625">
    <name>Ubud, Bali</name>
  </wpt>
</gpx>
```

## Project Structure

```
MyBaliMap/
├── App/
│   ├── MyBaliMapApp.swift       — @main entry point
│   └── ContentView.swift        — TabView (Map / Saved)
├── Models/
│   ├── Place.swift              — Place data model
│   └── Category.swift           — Category data model
├── Views/
│   ├── MapScreen.swift          — Screen 1: map + form
│   ├── SavedPlacesView.swift    — Screen 2: saved list
│   ├── PlaceRowView.swift       — Row in saved list
│   ├── CategoryChipView.swift   — Capsule chip component
│   └── MapView.swift            — MapLibre wrapper
├── Managers/
│   ├── LocationManager.swift    — CoreLocation singleton
│   ├── PersistenceManager.swift — JSON persistence
│   ├── RoutingManager.swift     — A* routing engine
│   ├── NavigationManager.swift  — Route orchestration
│   └── AirDropManager.swift     — Share/import places
└── Helpers/
    ├── Constants.swift          — App-wide constants
    └── Utilities.swift          — Extensions & formatters
```

## Development Phases

1. ✅ Project skeleton & data models
2. ✅ LocationManager + MapView (Apple MapKit, live GPS, airplane mode)
3. ✅ PersistenceManager + category chip UI + AddCategorySheet
4. ✅ Form (note input, 20-char limit + counter, category chips, Add Location)
5. ✅ SavedPlacesView + distance calculation + edit mode with multi-select delete
6. ✅ RoutingManager (A* on road graph with MinHeap + haversine heuristic)
7. ✅ Route rendering (info bar, ETA, mode toggle) + Apple Maps fallback
8. ✅ AirDrop sharing + import handler + context menu
9. ✅ Polish (accessibility, haptics, toast with undo, permission gate)
