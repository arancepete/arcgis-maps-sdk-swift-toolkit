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

import SwiftUI
import ArcGIS

/// Manages the state for a `BasemapGallery`.
@MainActor
public class BasemapGalleryViewModel: ObservableObject {
    /// Creates a `BasemapGalleryViewModel`. Uses the given array of basemap gallery items.
    /// - Remark: If `items` is empty, ArcGIS Online's developer basemaps will
    /// be loaded and added to `items`.
    /// - Parameters:
    ///   - geoModel: A geo model.
    ///   - items: A list of pre-defined base maps to display.
    public init(
        geoModel: GeoModel? = nil,
        items: [BasemapGalleryItem] = []
    ) {
        self.items = items
        self.geoModel = geoModel
        geoModelDidChange(nil)
        
        if items.isEmpty {
            // We have no basemap items, so fetch the
            // developer basemaps from AGOL.
            fetchBasemaps(
                from: Portal.arcGISOnline(isLoginRequired: false),
                useDeveloperBasemaps: true
            )
        }
    }
    
    /// Creates an instance using the given portal to retrieve basemaps.
    /// - Parameters:
    ///   - geoModel: A geo model.
    ///   - portal: The portal to use to load basemaps.
    public init(
        _ geoModel: GeoModel? = nil,
        portal: Portal
    ) {
        items = []
        self.geoModel = geoModel
        geoModelDidChange(nil)

        self.portal = portal
        portalDidChange(portal)
    }
    
    /// The error generated by fetching the `Basemaps` from the `Portal`.
    @Published
    public var fetchBasemapsError: Error? = nil
    
    /// The error signifying the spatial reference of the ``geoModel`` and the spatial reference of
    /// the ``currentItem`` do not match.
    @Published
    public private(set) var spatialReferenceMismatchError: SpatialReferenceMismatchError? = nil

    /// If the `GeoModel` is not loaded when passed to the `BasemapGalleryViewModel`, then
    /// the geoModel will be immediately loaded. The spatial reference of geoModel dictates which
    /// basemaps from the gallery are enabled. When an enabled basemap is selected by the user,
    /// the geoModel will have its basemap replaced with the selected basemap.
    public var geoModel: GeoModel? {
        didSet {
            geoModelDidChange(oldValue)
        }
    }
    
    /// The `Portal` object, if any. Setting the portal will automatically fetch it's basemaps
    /// and replace the ``items`` array with the fetched basemaps.
    public var portal: Portal? {
        didSet {
            portalDidChange(oldValue)
        }
    }

    /// The list of basemaps shown in the gallery.
    @Published
    public var items: [BasemapGalleryItem]
    
    /// The `BasemapGalleryItem` representing the `GeoModel`'s current basemap. This may be a
    /// basemap which does not exist in the gallery.
    @Published
    public private(set) var currentItem: BasemapGalleryItem? = nil {
        didSet {
            guard let item = currentItem else { return }
            geoModel?.basemap = item.basemap
        }
    }
    
    private var fetchBasemapsTask: Task<Void, Never>?
    
    /// Handles changes to the `geoModel` property.
    /// - Parameter previousGeoModel: The previously set `GeoModel`.
    func geoModelDidChange(_ previousGeoModel: GeoModel?) {
        guard let geoModel = geoModel else { return }
        if geoModel.loadStatus != .loaded {
            Task { await load(geoModel: geoModel) }
        }
    }
    
    /// Handles changes to the `portal` property.
    /// - Parameter previousPortal: The previously set `Portal`.
    func portalDidChange(_ previousPortal: Portal?) {
        // Remove all items from `items`.
        items.removeAll()

        guard let portal = portal else { return }
        fetchBasemaps(from: portal)
    }
    
    /// This attempts to set ``currentItem``; it will be set only if it's spatial reference
    /// matches with the ``geoModel``'s spatial reference. Otherwise ``currentItem``
    /// will be unchanged.
    /// - Parameter basemapGalleryItem: The new, potential, `BasemapGalleryItem`.
    @MainActor
    func setCurrentItem(
        _ basemapGalleryItem: BasemapGalleryItem
    ) {
        // Reset the mismatch error.
        spatialReferenceMismatchError = nil
        
        if let geoModel = geoModel {
            Task {
                // Ensure the geoModel is loaded.
                try await geoModel.load()
                
                // Update the basemap gallery item's `spatialReferenceStatus`.
                try await basemapGalleryItem.updateSpatialReferenceStatus(
                    geoModel.actualSpatialReference
                )
                
                switch basemapGalleryItem.spatialReferenceStatus {
                case .match, .unknown:
                    currentItem = basemapGalleryItem
                case .noMatch:
                    spatialReferenceMismatchError = SpatialReferenceMismatchError(
                        basemapSpatialReference: basemapGalleryItem.spatialReference,
                        geoModelSpatialReference: geoModel.actualSpatialReference
                    )
                }
            }
        } else {
            // No geoModel so no SR checking possible; just set `currentItem`.
            currentItem = basemapGalleryItem
        }
    }
}

private extension BasemapGalleryViewModel {
    /// Fetches the basemaps from the given portal and appends `items` with
    /// items created from the fetched basemaps.
    /// - Parameters:
    ///   - portal: Portal to fetch basemaps from
    ///   - useDeveloperBasemaps: If `true`, will always use the portal's developer basemaps. If
    ///   `false`, it will use either the portal's basemaps or vector basemaps, depending on the value of
    ///   `portal.portalInfo.useVectorBasemaps`.
    func fetchBasemaps(
        from portal: Portal,
        useDeveloperBasemaps: Bool = false
    ) {
        fetchBasemapsTask?.cancel()
        fetchBasemapsTask = Task {
            do {
                try await portal.load()
                
                let basemaps: [Basemap]
                if useDeveloperBasemaps {
                    basemaps = try await portal.developerBasemaps
                } else if let portalInfo = portal.info,
                          portalInfo.useVectorBasemaps {
                    basemaps = try await portal.vectorBasemaps
                } else {
                    basemaps = try await portal.basemaps
                }
                items += basemaps.map { BasemapGalleryItem(basemap: $0) }
            } catch {
                fetchBasemapsError = error
            }
        }
    }
    
    /// Loads the given `GeoModel` then sets `currentItem` to an item
    /// created with the geoModel's basemap.
    /// - Parameter geoModel: The `GeoModel` to load.
    func load(geoModel: GeoModel) async {
        try? await geoModel.load()
        if let basemap = geoModel.basemap {
            currentItem = BasemapGalleryItem(basemap: basemap)
        } else {
            currentItem = nil
        }
    }
}

/// An error describing a `SpatialReference` mismatch between a `GeoModel` and a `Basemap`.
public struct SpatialReferenceMismatchError: Error {
    /// The basemap's spatial reference.
    public let basemapSpatialReference: SpatialReference?
    
    /// The geomodel's spatial reference.
    public let geoModelSpatialReference: SpatialReference?
}

extension SpatialReferenceMismatchError: Equatable {}

extension GeoModel {
    /// The actual spatial reference of the `GeoModel`.
    /// - Remark:
    /// - For `Map`, it is map's `spatialReference`.
    /// - For `Scene`, if the `sceneViewTilingScheme` is `webMercator`, then `actualSpatialReference`
    /// is `webMercator`. Otherwise scene's `spatialReference`.
    var actualSpatialReference: SpatialReference? {
        (self as? ArcGIS.Scene)?.sceneViewTilingScheme == .webMercator ?
        SpatialReference.webMercator :
        spatialReference
    }
}
