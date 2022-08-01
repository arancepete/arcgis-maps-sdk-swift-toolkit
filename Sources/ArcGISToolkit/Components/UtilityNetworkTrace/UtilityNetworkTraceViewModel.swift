// Copyright 2022 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import Foundation
import SwiftUI

@MainActor final class UtilityNetworkTraceViewModel: ObservableObject {
    // MARK: Published Properties
    
    /// A list of completed traces.
    @Published private(set) var completedTraces = [Trace]()
    
    /// The available named trace configurations.
    @Published private(set) var configurations = [UtilityNamedTraceConfiguration]() {
        didSet {
            if configurations.isEmpty {
                userWarning = "No trace types found."
            }
        }
    }
    
    /// The utility network on which traces will be ran.
    @Published private(set) var network: UtilityNetwork?
    
    /// The trace currently under configuration.
    @Published var pendingTrace = Trace()
    
    /// The index of the selected trace.
    @Published private(set) var selectedTraceIndex: Int? {
        didSet {
            if let lastIndex = oldValue {
                changeSelectedStateForTrace(
                    at: lastIndex,
                    to: false
                )
            }
            if let currentIndex = selectedTraceIndex {
                changeSelectedStateForTrace(
                    at: currentIndex,
                    to: true
                )
            }
        }
    }
    
    /// Warning message presented to the user
    @Published var userWarning = ""
    
    /// A Boolean value indicating if the pending trace is configured to the point that it can be run.
    var canRunTrace: Bool {
        network != nil &&
        pendingTrace.configuration != nil &&
        !pendingTrace.startingPoints.isEmpty
    }
    
    /// The map's utility networks.
    var networks: [UtilityNetwork] {
        return map.utilityNetworks
    }
    
    /// The overlay on which trace graphics will be drawn.
    private var graphicsOverlay: GraphicsOverlay
    
    /// A map containing one or more utility networks.
    private var map: Map
    
    /// Starting points programmatically provided to the trace tool.
    var externalStartingPoints = [UtilityNetworkTraceStartingPoint]() {
        didSet {
            Task {
                await addExternalStartingPoints()
            }
        }
    }
    
    /// The selected trace.
    var selectedTrace: Trace? {
        if let index = selectedTraceIndex {
            return completedTraces[index]
        } else {
            return nil
        }
    }
    
    /// Performs required setup.
    ///
    /// - Parameters:
    ///   - map: The map to be loaded that contains at least one utility network.
    ///   - graphicsOverlay: The overlay on which trace graphics will be drawn.
    ///   - startingPoints: Starting points programmatically provided to the trace tool.
    ///   - autoLoad: If set `false`, `load()` will need to be manually called.
    init(
        map: Map,
        graphicsOverlay: GraphicsOverlay,
        startingPoints: [UtilityNetworkTraceStartingPoint],
        autoLoad: Bool = true
    ) {
        self.map = map
        self.graphicsOverlay = graphicsOverlay
        self.externalStartingPoints = startingPoints
        if autoLoad {
            Task { await load() }
        }
    }
    
    /// Deletes the provided starting point from the pending trace.
    /// - Parameter startingPoint: The starting point to be deleted.
    func delete(_ startingPoint: UtilityNetworkTraceStartingPoint) {
        pendingTrace.startingPoints.removeAll {
            $0 == startingPoint
        }
        if let graphic = startingPoint.graphic {
            graphicsOverlay.removeGraphic(graphic)
        }
    }
    
    /// Deletes all of the completed traces.
    func deleteAllTraces() {
        selectedTraceIndex = nil
        completedTraces.forEach { traceResult in
            graphicsOverlay.removeGraphics(traceResult.startingPoints.compactMap { $0.graphic })
            graphicsOverlay.removeGraphics(traceResult.graphics)
        }
        completedTraces.removeAll()
    }
    
    /// Returns a feature for the given utility element
    /// - Parameter element: The utility element to query the network for
    /// - Returns: A feature for the given element
    func feature(for element: UtilityElement) async -> ArcGISFeature? {
        do {
            return try await network?.getFeatures(for: [element]).first ?? nil
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Manually loads the components necessary to use the trace tool.
    func load() async {
        do {
            try await map.load()
            for network in map.utilityNetworks {
                try await network.load()
            }
        } catch {
            print(error.localizedDescription)
        }
        network = map.utilityNetworks.first
        configurations = await utilityNamedTraceConfigurations(from: map)
        if map.utilityNetworks.isEmpty {
            userWarning = "No utility networks found."
        }
        await addExternalStartingPoints()
    }
    
    /// Selects the next trace from the list of completed traces.
    func selectNextTrace() {
        if let current = selectedTraceIndex {
            if current + 1 <= completedTraces.count - 1 {
                selectedTraceIndex = current + 1
            } else {
                selectedTraceIndex = 0
            }
        }
    }
    
    /// Selects the previous trace from the list of completed traces.
    func selectPreviousTrace() {
        if let current = selectedTraceIndex {
            if current - 1 >= 0 {
                selectedTraceIndex = current - 1
            } else {
                selectedTraceIndex = completedTraces.count - 1
            }
        }
    }
    
    /// Updates the fractional portion of an edge based starting point.
    /// - Parameters:
    ///   - startingPoint: The starting point to be updated.
    ///   - newValue: A fraction along the starting point's edge.
    func setFractionAlongEdgeFor(
        startingPoint: UtilityNetworkTraceStartingPoint,
        to newValue: Double
    ) {
        pendingTrace.startingPoints.first {
            $0 == startingPoint
        }?.utilityElement?.fractionAlongEdge = newValue
        if let geometry = startingPoint.geoElement.geometry,
           let polyline = geometry as? Polyline {
            startingPoint.graphic?.geometry = GeometryEngine.point(
                along: polyline,
                atDistance: GeometryEngine.length(of: geometry) * newValue
            )
        }
    }
    
    /// Changes the selected network.
    ///
    /// This function also clears any set starting points in the pending trace and reloads the list of available
    /// trace configurations.
    /// - Parameter network: The new utility network to be selected.
    func setNetwork(_ network: UtilityNetwork) {
        self.network = network
        pendingTrace.startingPoints.removeAll()
        Task {
            configurations = await utilityNamedTraceConfigurations(from: map)
        }
    }
    
    /// Updates the pending trace's configuration and name, if applicable.
    ///
    /// The pending trace's name will only be updated if the user hasn't specified one already.
    /// - Parameter configuration: The selected configuration for the pending trace.
    func setPendingTrace(configuration: UtilityNamedTraceConfiguration) {
        pendingTrace.configuration = configuration
        if !pendingTrace.userDidSpecifyName {
            pendingTrace.name = "\(configuration.name) \((completedTraces.filter({ $0.configuration == configuration }).count + 1).description)"
        }
    }
    
    /// Adds a new starting point to the pending trace.
    /// - Parameters:
    ///   - point: A point on the map in screen coordinates.
    ///   - mapPoint: A point on the map in map coordinates.
    ///   - proxy: Provides a method of layer identification.
    func makeStartingPoint(
        at point: CGPoint,
        mapPoint: Point,
        with proxy: MapViewProxy
    ) async {
        let identifyLayerResults = try? await proxy.identifyLayers(
            screenPoint: point,
            tolerance: 10
        )
        for layerResult in identifyLayerResults ?? [] {
            for geoElement in layerResult.geoElements {
                let startingPoint = UtilityNetworkTraceStartingPoint(
                    geoElement: geoElement,
                    mapPoint: mapPoint
                )
                await processAndAdd(startingPoint)
            }
        }
    }
    
    /// Asynchronously sets the nullable members of the provided starting point and adds it to the pending
    /// trace.
    /// - Parameters:
    ///   - startingPoint: The starting point to be processed and added to the pending trace.
    func processAndAdd(_ startingPoint: UtilityNetworkTraceStartingPoint) async {
        guard let feature = startingPoint.geoElement as? ArcGISFeature,
              let globalid = feature.globalID else {
            userWarning = "Element could not be identified"
            return
        }
        
        // Block duplicate starting point selection
        guard !pendingTrace.startingPoints.contains(where: { startingPoint in
            return startingPoint.utilityElement?.globalID == globalid
        }) else {
            userWarning = "Duplicate starting points cannot be added"
            return
        }
        
        guard let network = self.network,
              let geometry = feature.geometry,
              let symbol = try? await (feature.featureTable?.layer as? FeatureLayer)?
            .renderer?
            .symbol(for: feature)?
            .makeSwatch(scale: 1.0),
              let utilityElement = network.makeElement(arcGISFeature: feature) else { return }
        
        if utilityElement.networkSource.kind == .edge && geometry is Polyline {
            if let mapPoint = startingPoint.mapPoint {
                utilityElement.fractionAlongEdge = fractionAlongEdge(
                    of: geometry,
                    at: mapPoint
                )
            } else {
                utilityElement.fractionAlongEdge = 0.5
            }
        } else if utilityElement.networkSource.kind == .junction &&
                    utilityElement.assetType.terminalConfiguration?.terminals.count ?? 0 > 1 {
            utilityElement.terminal = utilityElement.assetType.terminalConfiguration?.terminals.first
        }
        
        let graphic = Graphic(
            geometry: startingPoint.mapPoint ?? feature.geometry?.extent.center,
            symbol: SimpleMarkerSymbol(
                style: .cross,
                color: UIColor(self.pendingTrace.color),
                size: 20
            )
        )
        
        var newStartingPoint = startingPoint
        newStartingPoint.graphic = graphic
        newStartingPoint.image = symbol
        newStartingPoint.utilityElement = utilityElement
        
        graphicsOverlay.addGraphic(graphic)
        pendingTrace.startingPoints.append(newStartingPoint)
    }
    
    func setTerminalConfigurationFor(
        startingPoint: UtilityNetworkTraceStartingPoint,
        to newValue: UtilityTerminal
    ) {
        pendingTrace.startingPoints.first {
            $0 == startingPoint
        }?.utilityElement?.terminal = newValue
        objectWillChange.send()
    }
    
    /// Runs the pending trace and stores it into the list of completed traces.
    /// - Returns: A Boolean value indicating whether the trace was successful or not.
    func trace() async -> Bool {
        guard let configuration = pendingTrace.configuration,
              let network = network else { return false }
        
        let minStartingPoints = configuration.minimumStartingLocations.rawValue
        
        guard pendingTrace.startingPoints.count >= minStartingPoints else {
            userWarning = "Please set at least \(minStartingPoints) starting location\(minStartingPoints > 1 ? "s" : "")."
            return false
        }
        
        let parameters = UtilityTraceParameters(
            namedTraceConfiguration: configuration,
            startingLocations: pendingTrace.startingPoints.compactMap { $0.utilityElement }
        )
        
        let traceResults: [UtilityTraceResult]
        
        do {
            traceResults = try await network.trace(traceParameters: parameters)
        } catch(let serviceError as ServiceError) {
            if let reason = serviceError.failureReason {
                userWarning = reason
            }
            return false
        } catch {
            userWarning = "An unknown error occurred"
            return false
        }
        
        var assets = [String: [String: [UtilityElement]]]()
        for result in traceResults {
            switch result {
            case let result as UtilityElementTraceResult:
                result.elements.forEach { element in
                    var assetGroup = assets[element.assetGroup.name, default: [:]]
                    var assetTypeGroup = assetGroup[element.assetType.name, default: []]
                    assetTypeGroup.append(element)
                    assetGroup.updateValue(
                        assetTypeGroup,
                        forKey: element.assetType.name
                    )
                    assets.updateValue(
                        assetGroup,
                        forKey: element.assetGroup.name
                    )
                }
                pendingTrace.assetCount = result.elements.count
                pendingTrace.assets = assets
            case let result as UtilityGeometryTraceResult:
                let createGraphic: ((Geometry, SimpleLineSymbol.Style, Color) -> (Graphic)) = { geometry, style, color in
                    return Graphic(
                        geometry: geometry,
                        symbol: SimpleLineSymbol(
                            style: style,
                            color: UIColor(color),
                            width: 5.0
                        )
                    )
                }
                if let polygon = result.polygon {
                    let graphic = createGraphic(polygon, .solid, pendingTrace.color)
                    graphicsOverlay.addGraphic(graphic)
                    pendingTrace.graphics.append(graphic)
                }
                if let polyline = result.polyline {
                    let graphic = createGraphic(polyline, .dash, pendingTrace.color)
                    graphicsOverlay.addGraphic(graphic)
                    pendingTrace.graphics.append(graphic)
                }
                if let multipoint = result.multipoint {
                    let graphic = createGraphic(multipoint, .dot, pendingTrace.color)
                    graphicsOverlay.addGraphic(graphic)
                    pendingTrace.graphics.append(graphic)
                }
                pendingTrace.utilityGeometryTraceResult = result
            case let result as UtilityFunctionTraceResult:
                result.functionOutputs.forEach { functionOutput in
                    pendingTrace.functionOutputs.append(functionOutput)
                }
                pendingTrace.utilityFunctionTraceResult = result
            default:
                break
            }
        }
        completedTraces.append(pendingTrace)
        selectedTraceIndex = completedTraces.count - 1
        pendingTrace = Trace()
        await addExternalStartingPoints()
        return true
    }
    
    /// Updates the matching completed trace.
    /// - Parameter newValue: The new completed trace.
    func update(completedTrace newValue: Trace) {
        guard let traceIndex = completedTraces.firstIndex( where: { trace in
            trace == newValue
        }) else { return }
        completedTraces[traceIndex] = newValue
    }
    
    // MARK: Private Methods
    
    /// Adds programatic starting points to the pending trace.
    private func addExternalStartingPoints() async {
        for startingPoint in externalStartingPoints {
            await processAndAdd(startingPoint)
        }
    }
    
    /// Changes the selected state of the graphics for the completed trace at the provided index.
    /// - Parameters:
    ///   - index: The index of the completed trace.
    ///   - isSelected: The new selection state.
    private func changeSelectedStateForTrace(
        at index: Int,
        to isSelected: Bool
    ) {
        guard index >= 0, index <= completedTraces.count - 1 else { return }
        _ = completedTraces[index].graphics.map { $0.isSelected = isSelected }
        _ = completedTraces[index].startingPoints.map { $0.graphic?.isSelected = isSelected }
    }
    
    /// Loads the named trace configurations in the network.
    /// Returns the named trace configurations in the network on the provided map.
    /// - Parameter map: A web map containing one or more utility networks.
    func utilityNamedTraceConfigurations(from map: Map) async -> [UtilityNamedTraceConfiguration] {
        guard let network = network else { return [] }
        do {
            return try await map.getNamedTraceConfigurations(from: network)
        } catch {
            print(
                "Failed to retrieve configurations.",
                error.localizedDescription
            )
            return []
        }
    }
}

extension UtilityNetworkTraceViewModel {
    /// Finds the location on the line nearest the input point, expressed as the fraction along the line’s total
    /// geodesic length.
    /// - Parameters:
    ///   - inputGeometry: The line to be measured.
    ///   - point: A location along the line.
    private func fractionAlongEdge(
        of inputGeometry: Geometry,
        at point: Point
    ) -> Double {
        var geometry = inputGeometry
        // Remove Z
        if geometry.hasZ {
            geometry = GeometryEngine.makeGeometry(
                from: geometry,
                z: nil
            )
        }
        
        // Confirm spatial references match
        if let spatialReference = point.spatialReference,
           spatialReference != geometry.spatialReference,
           let projectedGeometry = GeometryEngine.project(
            geometry,
            into: spatialReference
           ) {
            geometry = projectedGeometry
        }
        
        return GeometryEngine.polyline(
            geometry as! Polyline,
            fractionalLengthClosestTo: point,
            tolerance: 10
        )
    }
}
