// Copyright 2021 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

import XCTest
import ArcGIS
import ArcGISToolkit
import SwiftUI
import Combine

@MainActor
class BasemapGalleryItemTests: XCTestCase {
    //
    // Test Design: https://devtopia.esri.com/runtime/common-toolkit/blob/master/designs/BasemapGallery/BasemapGallery_Test_Design.md
    //
    func testInit() async throws {
        let basemap = Basemap.lightGrayCanvas()
        var item = BasemapGalleryItem(basemap: basemap)
        
        var isLoading = try await item.$isLoading.compactMap({ $0 }).dropFirst().first
        var loading = try XCTUnwrap(isLoading)
        XCTAssertFalse(loading, "Item is not loading.")
        XCTAssertTrue(item.basemap === basemap)
        XCTAssertEqual(item.name, "Light Gray Canvas")
        XCTAssertNil(item.description)
        XCTAssertNotNil(item.thumbnail)
        XCTAssertNil(item.loadBasemapsError)

        // Test with overrides.
        let thumbnail = UIImage(systemName: "magnifyingglass")
        XCTAssertNotNil(thumbnail)
        item = BasemapGalleryItem(
            basemap: basemap,
            name: "My Basemap",
            description: "Basemap description",
            thumbnail: thumbnail
        )
        
        isLoading = try await item.$isLoading.compactMap({ $0 }).dropFirst().first
        loading = try XCTUnwrap(isLoading)
        XCTAssertFalse(loading, "Item is not loading.")
        XCTAssertEqual(item.name, "My Basemap")
        XCTAssertEqual(item.description, "Basemap description")
        XCTAssertEqual(item.thumbnail, thumbnail)
        XCTAssertNil(item.loadBasemapsError)

        // Test with portal item.
        item = BasemapGalleryItem(
            basemap: Basemap(
                item: PortalItem(
                    url: URL(string: "https://runtime.maps.arcgis.com/home/item.html?id=46a87c20f09e4fc48fa3c38081e0cae6")!
                )!
            )
        )
        
        isLoading = try await item.$isLoading.compactMap({ $0 }).dropFirst().first
        loading = try XCTUnwrap(isLoading)
        XCTAssertFalse(loading, "Item is not loading.")
        XCTAssertEqual(item.name, "OpenStreetMap Blueprint")
        XCTAssertEqual(item.description, "<div><div style=\'margin-bottom:3rem;\'><div><div style=\'max-width:100%; display:inherit;\'><p style=\'margin-top:0px; margin-bottom:1.5rem;\'><span style=\'font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'>This web map presents a vector basemap of OpenStreetMap (OSM) data hosted by Esri. Esri created this vector tile basemap from the </span><a href=\'https://daylightmap.org/\' rel=\'nofollow ugc\' style=\'color:rgb(0, 121, 193); text-decoration-line:none; font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'>Daylight map distribution</a><span style=\'font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'> of OSM data, which is supported by </span><b><font style=\'font-family:inherit;\'><span style=\'font-family:inherit;\'>Facebook</span></font> </b><span style=\'font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'>and supplemented with additional data from </span><font style=\'font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'><b>Microsoft</b>. It presents the map in a cartographic style is like a blueprint technical drawing. The OSM Daylight map will be updated every month with the latest version of OSM Daylight data. </font></p><div style=\'font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'>OpenStreetMap is an open collaborative project to create a free editable map of the world. Volunteers gather location data using GPS, local knowledge, and other free sources of information and upload it. The resulting free map can be viewed and downloaded from the OpenStreetMap site: <a href=\'https://www.openstreetmap.org/\' rel=\'nofollow ugc\' style=\'color:rgb(0, 121, 193); text-decoration-line:none; font-family:inherit;\' target=\'_blank\'>www.OpenStreetMap.org</a>. Esri is a supporter of the OSM project and is excited to make this enhanced vector basemap available to the ArcGIS user and developer communities.</div></div></div></div></div><div style=\'margin-bottom:3rem; display:inherit; font-family:&quot;Avenir Next W01&quot;, &quot;Avenir Next W00&quot;, &quot;Avenir Next&quot;, Avenir, &quot;Helvetica Neue&quot;, sans-serif; font-size:16px;\'><div style=\'display:inherit;\'></div></div>")
        XCTAssertNotNil(item.thumbnail)
        XCTAssertNil(item.loadBasemapsError)
    }
    
    func testLoadBasemapError() async throws {
        let item = BasemapGalleryItem(
            basemap: Basemap(
                item: PortalItem(
                    url: URL(string: "https://runtime.maps.arcgis.com/home/item.html?id=4a3922d6d15f405d8c2b7a448a7fbad2")!
                )!
            )
        )

        let isLoading = try await item.$isLoading.compactMap({ $0 }).dropFirst().first
        let loading = try XCTUnwrap(isLoading)
        XCTAssertFalse(loading, "Item is not loading.")
        XCTAssertNotNil(item.loadBasemapsError)
    }
    
    func testSpatialReferenceStatus() async throws {
        let basemap = Basemap.lightGrayCanvas()
        let item = BasemapGalleryItem(basemap: basemap)
        
    }
    
    func testSpatialReference() async throws {
        
    }

    
    /*

    
    
    func testAcceptSuggestion() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        model.currentQuery = "Magers & Quinn Booksellers"
        
        Task { model.updateSuggestions() }
        
        // Get suggestion
        let suggestions = try await model.$suggestions.compactMap({$0}).first
        let suggestion = try XCTUnwrap(suggestions?.get().first)
        
        Task { model.acceptSuggestion(suggestion) }
        
        let results = try await model.$results.compactMap({$0}).first
        let result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(model.suggestions)
        
        // With only one results, model should set `selectedResult` property.
        XCTAssertEqual(result.first!, model.selectedResult)
    }
    
    func testActiveSource() async throws {
        let activeSource = LocatorSearchSource()
        activeSource.displayName = "Simple Locator"
        let model = BasemapGalleryViewModel(
            activeSource: activeSource,
            sources: [LocatorSearchSource()]
        )
        
        model.currentQuery = "Magers & Quinn Booksellers"
        
        Task { model.commitSearch() }
        
        let results = try await model.$results.compactMap({$0}).first
        let result = try XCTUnwrap(results?.get().first)
        XCTAssertEqual(result.owningSource.displayName, activeSource.displayName)
        
        Task { model.updateSuggestions() }
        
        let suggestions = try await model.$suggestions.compactMap({$0}).first
        let suggestion = try XCTUnwrap(suggestions?.get().first)
        XCTAssertEqual(suggestion.owningSource.displayName, activeSource.displayName)
    }
    
    func testCommitSearch() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // No search - results are nil.
        XCTAssertNil(model.results)
        
        // Search with no results - result count is 0.
        model.currentQuery = "No results found blah blah blah blah"
        
        Task { model.commitSearch() }
        
        var results = try await model.$results.compactMap({$0}).first
        var result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 0)
        XCTAssertNil(model.selectedResult)
        XCTAssertNil(model.suggestions)
        
        // Search with one result.
        model.currentQuery = "Magers & Quinn Booksellers"
        
        Task { model.commitSearch() }
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
        
        // One results automatically populates `selectedResult`.
        XCTAssertEqual(result.first!, model.selectedResult)
        XCTAssertNil(model.suggestions)
        
        // Search with multiple results.
        model.currentQuery = "Magers & Quinn"
        
        Task { model.commitSearch() }
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        XCTAssertNil(model.selectedResult)
        XCTAssertNil(model.suggestions)
        
        model.selectedResult = result.first!
        
        Task { model.commitSearch() }
        
        results = try await model.$results.compactMap({$0}).dropFirst().first
        result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        XCTAssertNil(model.selectedResult)
    }
    
    func testCurrentQuery() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // Empty `currentQuery` should produce nil results and suggestions.
        model.currentQuery = ""
        XCTAssertNil(model.results)
        XCTAssertNil(model.suggestions)
        
        // Valid `currentQuery` should produce non-nil results.
        model.currentQuery = "Coffee"
        
        Task { model.commitSearch() }
        
        let results = try await model.$results.compactMap({$0}).first
        XCTAssertNotNil(results)
        
        // Changing the `currentQuery` should set results to nil.
        model.currentQuery = "Coffee in Portland"
        XCTAssertNil(model.results)
        
        Task { model.updateSuggestions() }
        
        let suggestions = try await model.$suggestions.compactMap({$0}).first
        XCTAssertNotNil(suggestions)
        
        // Changing the `currentQuery` should set suggestions to nil.
        model.currentQuery = "Coffee in Edinburgh"
        XCTAssertNil(model.suggestions)
        
        // Changing current query after search with 1 result
        // should set `selectedResult` to nil
        model.currentQuery = "Magers & Quinn Bookseller"
        
        Task { model.commitSearch() }
        
        _ = try await model.$results.compactMap({$0}).first
        XCTAssertNotNil(model.selectedResult)
        model.currentQuery = "Hotel"
        XCTAssertNil(model.selectedResult)
    }
    
    func testIsEligibleForRequery() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // Set queryArea to Chippewa Falls
        model.queryArea = Polygon.chippewaFalls
        model.geoViewExtent = Polygon.chippewaFalls.extent
        model.currentQuery = "Coffee"
        
        Task { model.commitSearch() }
        
        _ = try await model.$results.compactMap({$0}).first
        XCTAssertFalse(model.isEligibleForRequery)
        
        // Offset extent by 10% - isEligibleForRequery should still be `false`.
        var builder = EnvelopeBuilder(envelope: model.geoViewExtent)
        let tenPercentWidth = model.geoViewExtent!.width * 0.1
        builder.offsetBy(x: tenPercentWidth, y: 0.0)
        var newExtent = builder.toGeometry() as! Envelope
        
        model.geoViewExtent = newExtent
        XCTAssertFalse(model.isEligibleForRequery)
        
        // Offset extent by 50% - isEligibleForRequery should now be `true`.
        builder = EnvelopeBuilder(envelope: model.geoViewExtent)
        let fiftyPercentWidth = model.geoViewExtent!.width * 0.5
        builder.offsetBy(x: fiftyPercentWidth, y: 0.0)
        newExtent = builder.toGeometry() as! Envelope
        
        model.geoViewExtent = newExtent
        XCTAssertTrue(model.isEligibleForRequery)
        
        // Set queryArea to Chippewa Falls
        model.queryArea = Polygon.chippewaFalls
        model.geoViewExtent = Polygon.chippewaFalls.extent
        
        Task { model.commitSearch() }
        
        _ = try await model.$results.compactMap({$0}).dropFirst().first
        XCTAssertFalse(model.isEligibleForRequery)
        
        // Expand extent by 1.1x - isEligibleForRequery should still be `false`.
        builder = EnvelopeBuilder(envelope: model.geoViewExtent)
        builder.expand(factor: 1.1)
        newExtent = builder.toGeometry() as! Envelope
        
        model.geoViewExtent = newExtent
        XCTAssertFalse(model.isEligibleForRequery)
        
        // Expand extent by 1.5x - isEligibleForRequery should now be `true`.
        builder = EnvelopeBuilder(envelope: model.geoViewExtent)
        builder.expand(factor: 1.5)
        newExtent = builder.toGeometry() as! Envelope
        
        model.geoViewExtent = newExtent
        XCTAssertTrue(model.isEligibleForRequery)
    }
    
    func testQueryArea() async throws {
        let source = LocatorSearchSource()
        source.maximumResults = Int32.max
        let model = BasemapGalleryViewModel(sources: [source])
        
        // Set queryArea to Chippewa Falls
        model.queryArea = Polygon.chippewaFalls
        model.currentQuery = "Coffee"
        
        Task { model.commitSearch() }
        
        var results = try await model.$results.compactMap({$0}).first
        var result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        let resultGeometryUnion: Geometry = try XCTUnwrap(
            GeometryEngine.union(
                geometries: result.compactMap{ $0.geoElement?.geometry }
            )
        )
        
        XCTAssertTrue(
            GeometryEngine.contains(
                geometry1: model.queryArea!,
                geometry2: resultGeometryUnion
            )
        )
        
        model.currentQuery = "Magers & Quinn Booksellers"
        
        Task { model.commitSearch() }
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 0)
        
        model.queryArea = Polygon.minneapolis
        
        Task { model.commitSearch() }
        
        // A note about the use of `.dropFirst()`:
        // Because `model.results` is not changed between the previous call
        // to `model.commitSearch()` and the one right above, the
        // `try await model.$results...` call will return the last result
        // received (from the first `model.commitSearch()` call), which is
        // incorrect.  Calling `.dropFirst()` will remove that one
        // and will give us the next one, which is the correct one (the result
        // from the second `model.commitSearch()` call).
        results = try await model.$results.compactMap({$0}).dropFirst().first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
    }
    
    func testQueryCenter() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // Set queryCenter to Portland
        model.queryCenter = .portland
        model.currentQuery = "Coffee"
        
        Task { model.commitSearch() }
        
        var results = try await model.$results.compactMap({$0}).first
        var result = try XCTUnwrap(results?.get())
        
        var resultPoint = try XCTUnwrap(
            result.first?.geoElement?.geometry as? Point
        )
        
        var geodeticDistance = try XCTUnwrap (
            GeometryEngine.distanceGeodetic(
                point1: .portland,
                point2: resultPoint,
                distanceUnit: .meters,
                azimuthUnit: nil,
                curveType: .geodesic
            )
        )
        
        // First result within 1500m of Portland.
        XCTAssertLessThan(geodeticDistance.distance,  1500.0)
        
        // Set queryCenter to Edinburgh
        model.queryCenter = .edinburgh
        model.currentQuery = "Restaurants"
        
        Task { model.commitSearch() }
        
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        
        resultPoint = try XCTUnwrap(
            result.first?.geoElement?.geometry as? Point
        )
        
        // Web Mercator distance between .edinburgh and first result.
        geodeticDistance = try XCTUnwrap (
            GeometryEngine.distanceGeodetic(
                point1: .edinburgh,
                point2: resultPoint,
                distanceUnit: .meters,
                azimuthUnit: nil,
                curveType: .geodesic
            )
        )
        
        // First result within 100m of Edinburgh.
        XCTAssertLessThan(geodeticDistance.distance,  100)
    }
    
    func testRepeatSearch() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // Set queryArea to Chippewa Falls
        model.geoViewExtent = Polygon.chippewaFalls.extent
        model.currentQuery = "Coffee"
        
        Task { model.repeatSearch() }
        
        var results = try await model.$results.compactMap({$0}).first
        var result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        let resultGeometryUnion: Geometry = try XCTUnwrap(
            GeometryEngine.union(
                geometries: result.compactMap{ $0.geoElement?.geometry }
            )
        )
        
        XCTAssertTrue(
            GeometryEngine.contains(
                geometry1: model.geoViewExtent!,
                geometry2: resultGeometryUnion
            )
        )
        
        model.currentQuery = "Magers & Quinn Booksellers"
        
        Task { model.repeatSearch() }
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 0)
        
        model.geoViewExtent = Polygon.minneapolis.extent
        
        Task { model.repeatSearch() }
        
        results = try await model.$results.compactMap({$0}).dropFirst().first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
    }
    
    func testSearchResultMode() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        XCTAssertEqual(model.resultMode, .automatic)
        
        model.resultMode = .single
        model.currentQuery = "Magers & Quinn"
        
        Task { model.commitSearch() }
        
        var results = try await model.$results.compactMap({$0}).first
        var result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
        
        model.resultMode = .multiple
        
        Task { model.commitSearch() }
        
        results = try await model.$results.compactMap({$0}).dropFirst().first
        result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        model.currentQuery = "Coffee"
        
        Task { model.updateSuggestions() }
        
        let suggestionResults = try await model.$suggestions.compactMap({$0}).first
        let suggestions = try XCTUnwrap(suggestionResults?.get())
        
        let collectionSuggestion = try XCTUnwrap(suggestions.filter { $0.isCollection }.first)
        let singleSuggestion = try XCTUnwrap(suggestions.filter { !$0.isCollection }.first)
        
        model.resultMode = .automatic
        
        Task { model.acceptSuggestion(collectionSuggestion) }
        
        results = try await model.$results.compactMap({$0}).first
        result = try XCTUnwrap(results?.get())
        XCTAssertGreaterThan(result.count, 1)
        
        Task { model.acceptSuggestion(singleSuggestion) }
        
        results = try await model.$results.compactMap({$0}).dropFirst().first
        result = try XCTUnwrap(results?.get())
        XCTAssertEqual(result.count, 1)
    }
    
    func testUpdateSuggestions() async throws {
        let model = BasemapGalleryViewModel(sources: [LocatorSearchSource()])
        
        // No currentQuery - suggestions are nil.
        XCTAssertNil(model.suggestions)
        
        // UpdateSuggestions with no results - result count is 0.
        model.currentQuery = "No results found blah blah blah blah"
        
        Task { model.updateSuggestions() }
        
        var suggestionResults = try await model.$suggestions.compactMap({$0}).first
        var suggestions = try XCTUnwrap(suggestionResults?.get())
        XCTAssertEqual(suggestions.count, 0)
        
        // UpdateSuggestions with results.
        model.currentQuery = "Magers & Quinn"
        
        Task { model.updateSuggestions() }
        
        suggestionResults = try await model.$suggestions.compactMap({$0}).first
        suggestions = try XCTUnwrap(suggestionResults?.get())
        XCTAssertGreaterThanOrEqual(suggestions.count, 1)
        
        XCTAssertNil(model.selectedResult)
        XCTAssertNil(model.results)
    }
     */
}

//extension Polygon {
//    static var chippewaFalls: Polygon {
//        let builder = PolygonBuilder(spatialReference: .wgs84)
//        let _ = builder.add(point: Point(x: -91.59127653822401, y: 44.74770908213401, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -91.19322516572637, y: 44.74770908213401, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -91.19322516572637, y: 45.116100854348254, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -91.59127653822401, y: 45.116100854348254, spatialReference: .wgs84))
//        return builder.toGeometry() as! ArcGIS.Polygon
//    }
//    
//    static var minneapolis: Polygon {
//        let builder = PolygonBuilder(spatialReference: .wgs84)
//        let _ = builder.add(point: Point(x: -94.170821328662, y: 44.13656401114444, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -94.170821328662, y: 44.13656401114444, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -92.34544467133114, y: 45.824325577904446, spatialReference: .wgs84))
//        let _ = builder.add(point: Point(x: -92.34544467133114, y: 45.824325577904446, spatialReference: .wgs84))
//        return builder.toGeometry() as! ArcGIS.Polygon
//    }
//}
//
//extension Point {
//    static let edinburgh = Point(x: -3.188267, y: 55.953251, spatialReference: .wgs84)
//    static let portland = Point(x: -122.658722, y: 45.512230, spatialReference: .wgs84)
//}
//
