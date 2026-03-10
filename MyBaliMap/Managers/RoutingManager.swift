// RoutingManager.swift
// MyBaliMap
//
// Offline routing engine using A* algorithm on preprocessed road graph.
// Loads nodes.json + edges.json from app bundle into an adjacency list.
//
// Algorithm: A* with haversine heuristic
// Data: adjacency list [Int: [(neighborId, distance)]]
// Nearest-node: linear scan (acceptable for Bali-sized ~50k nodes)
// Fallback: straight-line polyline if graph files missing

import Foundation
import CoreLocation

// MARK: - Graph Models

struct GraphNode: Codable, Equatable {
    let id: Int
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct GraphEdge: Codable {
    let from: Int
    let to: Int
    let distance: Double  // meters
}

// MARK: - A* Priority Queue Entry

private struct AStarEntry: Comparable {
    let nodeId: Int
    let fScore: Double  // g + h

    static func < (lhs: AStarEntry, rhs: AStarEntry) -> Bool {
        lhs.fScore < rhs.fScore
    }
}

// MARK: - Min-Heap (for A* open set)

private struct MinHeap<T: Comparable> {
    private var elements: [T] = []

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }

    mutating func insert(_ element: T) {
        elements.append(element)
        siftUp(from: elements.count - 1)
    }

    mutating func extractMin() -> T? {
        guard !elements.isEmpty else { return nil }
        if elements.count == 1 { return elements.removeLast() }

        let min = elements[0]
        elements[0] = elements.removeLast()
        siftDown(from: 0)
        return min
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            if elements[child] < elements[parent] {
                elements.swapAt(child, parent)
                child = parent
            } else {
                break
            }
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        let count = elements.count

        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var smallest = parent

            if left < count && elements[left] < elements[smallest] {
                smallest = left
            }
            if right < count && elements[right] < elements[smallest] {
                smallest = right
            }
            if smallest == parent { break }

            elements.swapAt(parent, smallest)
            parent = smallest
        }
    }
}

// MARK: - Route Result

/// Result of a routing computation.
struct RouteResult {
    /// Ordered coordinates forming the route path.
    let coordinates: [CLLocationCoordinate2D]

    /// Total distance in meters.
    let distanceMeters: Double

    /// Number of graph nodes in the path.
    let nodeCount: Int

    /// Whether this is a fallback straight line (graph unavailable).
    let isStraightLine: Bool
}

// MARK: - Routing Manager

final class RoutingManager {

    // MARK: - State

    private var nodes: [Int: GraphNode] = [:]
    private var nodeArray: [GraphNode] = []    // For fast linear scan
    private var adjacencyList: [Int: [(neighborId: Int, distance: Double)]] = [:]
    private(set) var isGraphLoaded: Bool = false

    /// Number of nodes in the graph.
    var nodeCount: Int { nodes.count }

    /// Number of edges in the graph.
    var edgeCount: Int {
        adjacencyList.values.reduce(0) { $0 + $1.count } / 2  // undirected
    }

    // MARK: - Graph Loading

    /// Loads nodes.json and edges.json from the app bundle into memory.
    /// Call once at app launch (fast for Bali-sized graphs).
    func loadGraph() {
        guard let nodesURL = Bundle.main.url(forResource: "nodes", withExtension: "json"),
              let edgesURL = Bundle.main.url(forResource: "edges", withExtension: "json")
        else {
            print("⚠️ RoutingManager: Graph files not found in bundle. Routing will use straight-line fallback.")
            return
        }

        do {
            // Parse nodes
            let nodesData = try Data(contentsOf: nodesURL)
            let parsedNodes = try JSONDecoder().decode([GraphNode].self, from: nodesData)

            for node in parsedNodes {
                nodes[node.id] = node
            }
            nodeArray = parsedNodes

            // Parse edges and build adjacency list (undirected graph)
            let edgesData = try Data(contentsOf: edgesURL)
            let parsedEdges = try JSONDecoder().decode([GraphEdge].self, from: edgesData)

            for edge in parsedEdges {
                adjacencyList[edge.from, default: []].append(
                    (neighborId: edge.to, distance: edge.distance)
                )
                // Undirected: add reverse edge
                adjacencyList[edge.to, default: []].append(
                    (neighborId: edge.from, distance: edge.distance)
                )
            }

            isGraphLoaded = true
            print("✅ RoutingManager: Loaded \(parsedNodes.count) nodes, \(parsedEdges.count) edges.")
        } catch {
            print("⚠️ RoutingManager: Failed to parse graph: \(error.localizedDescription)")
        }
    }

    // MARK: - Nearest Node Search (Linear Scan)

    /// Finds the nearest graph node to a given coordinate.
    /// Uses linear scan — O(n) — acceptable for Bali-sized dataset (~50k nodes).
    func findNearestNode(to coordinate: CLLocationCoordinate2D) -> GraphNode? {
        guard !nodeArray.isEmpty else { return nil }

        var bestNode: GraphNode?
        var bestDistance: Double = .greatestFiniteMagnitude

        for node in nodeArray {
            let dist = haversineDistance(
                lat1: coordinate.latitude, lon1: coordinate.longitude,
                lat2: node.lat, lon2: node.lon
            )
            if dist < bestDistance {
                bestDistance = dist
                bestNode = node
            }
        }

        return bestNode
    }

    // MARK: - A* Routing

    /// Computes the shortest path using A* algorithm.
    ///
    /// - Parameters:
    ///   - start: Starting coordinate (e.g. user's GPS location)
    ///   - destination: Destination coordinate (e.g. a saved place)
    /// - Returns: `RouteResult` with path coordinates and distance,
    ///            or a straight-line fallback if graph is unavailable.
    func findRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> RouteResult {
        // Fallback: straight line if graph not loaded
        guard isGraphLoaded else {
            let distance = haversineDistance(
                lat1: start.latitude, lon1: start.longitude,
                lat2: destination.latitude, lon2: destination.longitude
            )
            return RouteResult(
                coordinates: [start, destination],
                distanceMeters: distance,
                nodeCount: 2,
                isStraightLine: true
            )
        }

        // Find nearest graph nodes to start and destination
        guard let startNode = findNearestNode(to: start),
              let endNode = findNearestNode(to: destination)
        else {
            let distance = haversineDistance(
                lat1: start.latitude, lon1: start.longitude,
                lat2: destination.latitude, lon2: destination.longitude
            )
            return RouteResult(
                coordinates: [start, destination],
                distanceMeters: distance,
                nodeCount: 2,
                isStraightLine: true
            )
        }

        // Same node — trivial path
        if startNode.id == endNode.id {
            return RouteResult(
                coordinates: [start, startNode.coordinate, destination],
                distanceMeters: 0,
                nodeCount: 1,
                isStraightLine: false
            )
        }

        // Run A*
        if let path = astar(from: startNode.id, to: endNode.id) {
            // Convert node IDs to coordinates
            var coordinates: [CLLocationCoordinate2D] = [start]  // Start from actual position
            var totalDistance: Double = 0

            for i in 0..<path.count {
                if let node = nodes[path[i]] {
                    let coord = node.coordinate
                    if let prev = coordinates.last {
                        totalDistance += haversineDistance(
                            lat1: prev.latitude, lon1: prev.longitude,
                            lat2: coord.latitude, lon2: coord.longitude
                        )
                    }
                    coordinates.append(coord)
                }
            }

            // Append actual destination
            if let last = coordinates.last {
                totalDistance += haversineDistance(
                    lat1: last.latitude, lon1: last.longitude,
                    lat2: destination.latitude, lon2: destination.longitude
                )
            }
            coordinates.append(destination)

            return RouteResult(
                coordinates: coordinates,
                distanceMeters: totalDistance,
                nodeCount: path.count,
                isStraightLine: false
            )
        }

        // A* found no path — fallback to straight line
        let distance = haversineDistance(
            lat1: start.latitude, lon1: start.longitude,
            lat2: destination.latitude, lon2: destination.longitude
        )
        return RouteResult(
            coordinates: [start, destination],
            distanceMeters: distance,
            nodeCount: 2,
            isStraightLine: true
        )
    }

    // MARK: - A* Implementation

    /// Core A* algorithm.
    /// Returns ordered list of node IDs from start to goal, or nil if no path.
    private func astar(from startId: Int, to goalId: Int) -> [Int]? {
        guard let goalNode = nodes[goalId] else { return nil }

        // g(n): cost from start to n
        var gScore: [Int: Double] = [startId: 0]

        // Parent map for path reconstruction
        var cameFrom: [Int: Int] = [:]

        // Open set (min-heap by f-score)
        var openSet = MinHeap<AStarEntry>()
        let startH = heuristic(nodeId: startId, goal: goalNode)
        openSet.insert(AStarEntry(nodeId: startId, fScore: startH))

        // Closed set
        var closedSet = Set<Int>()

        while let current = openSet.extractMin() {
            let currentId = current.nodeId

            // Goal reached
            if currentId == goalId {
                return reconstructPath(cameFrom: cameFrom, current: goalId)
            }

            // Skip if already processed
            if closedSet.contains(currentId) { continue }
            closedSet.insert(currentId)

            let currentG = gScore[currentId] ?? .greatestFiniteMagnitude

            // Explore neighbors
            guard let neighbors = adjacencyList[currentId] else { continue }

            for (neighborId, edgeDist) in neighbors {
                if closedSet.contains(neighborId) { continue }

                let tentativeG = currentG + edgeDist

                if tentativeG < (gScore[neighborId] ?? .greatestFiniteMagnitude) {
                    gScore[neighborId] = tentativeG
                    cameFrom[neighborId] = currentId

                    let h = heuristic(nodeId: neighborId, goal: goalNode)
                    let f = tentativeG + h
                    openSet.insert(AStarEntry(nodeId: neighborId, fScore: f))
                }
            }
        }

        return nil  // No path found
    }

    /// Reconstructs path from A* parent map.
    private func reconstructPath(cameFrom: [Int: Int], current: Int) -> [Int] {
        var path = [current]
        var node = current

        while let parent = cameFrom[node] {
            path.append(parent)
            node = parent
        }

        return path.reversed()
    }

    /// Heuristic function: haversine distance from node to goal (admissible).
    private func heuristic(nodeId: Int, goal: GraphNode) -> Double {
        guard let node = nodes[nodeId] else { return .greatestFiniteMagnitude }
        return haversineDistance(
            lat1: node.lat, lon1: node.lon,
            lat2: goal.lat, lon2: goal.lon
        )
    }

    // MARK: - Route Info Helpers

    /// Calculates total distance of a coordinate array in meters.
    func totalDistance(route: [CLLocationCoordinate2D]) -> Double {
        guard route.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<route.count {
            total += haversineDistance(
                lat1: route[i-1].latitude, lon1: route[i-1].longitude,
                lat2: route[i].latitude, lon2: route[i].longitude
            )
        }
        return total
    }

    /// Estimates travel time as a human-readable string.
    func estimatedTime(distanceMeters: Double, mode: TravelMode) -> String {
        let seconds = distanceMeters / mode.speedMPS
        let minutes = Int(ceil(seconds / 60))

        if minutes < 60 {
            return "\(minutes) min \(mode.rawValue.lowercased())"
        } else {
            let hours = minutes / 60
            let remainingMin = minutes % 60
            if remainingMin == 0 {
                return "\(hours) hr \(mode.rawValue.lowercased())"
            }
            return "\(hours) hr \(remainingMin) min \(mode.rawValue.lowercased())"
        }
    }

    /// Formats distance as human-readable string.
    func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    // MARK: - Haversine Distance

    /// Haversine formula: distance between two lat/lon points in meters.
    private func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let R = 6_371_000.0  // Earth radius in meters

        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

// MARK: - Travel Mode

enum TravelMode: String, CaseIterable {
    case walking = "Walking"
    case driving = "Driving"

    /// Average speed in meters per second.
    var speedMPS: Double {
        switch self {
        case .walking: return 1.4   // ~5 km/h
        case .driving: return 8.3   // ~30 km/h (Bali roads)
        }
    }

    /// SF Symbol for this mode.
    var iconName: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        }
    }
}
