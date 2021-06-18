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
import Combine
import ArcGIS

/// `OverviewMap` is a small, secondary `MapView` (sometimes called an "inset map"), superimposed
/// on an existing `GeoView`, which shows the visible extent of that `GeoView`.
public struct OverviewMap: View {
    /// The `GeoViewProxy` representing the main `GeoView`. The proxy is
    /// necessary for accessing `GeoView` functionality to get and set viewpoints.
    private(set) var proxy: GeoViewProxy?
    
    /// The `Map` displayed in the `OverviewMap`.
    private(set) var map: Map
    
    /// The fill symbol used to display the main `GeoView` extent.
    private(set) var extentSymbol: FillSymbol
    
    /// The factor to multiply the main `GeoView`'s scale by. The `OverviewMap` will display
    /// at the product of mainGeoViewScale * scaleFactor.
    private(set) var scaleFactor: Double
    
    /// The geometry of the extent `Graphic` displaying the main `GeoView`'s extent. Updating
    /// this property will update the display of the `OverviewMap`.
    @State private var extentGeometry: Geometry?
    
    /// The viewpoint of the `OverviewMap'`s `MapView`. Updating
    /// this property will update the display of the `OverviewMap`.
    @State private var overviewMapViewpoint: Viewpoint?
    
    /// Creates an `OverviewMap`.
    /// - Parameters:
    ///   - proxy: The `GeoViewProxy` representing the main map.
    ///   - map: The `Map` to display in the `OverviewMap`.
    ///   - extentSymbol: The `FillSymbol` used to display the main `GeoView`'s extent.
    ///   The default is a transparent `SimpleFillSymbol` with a red, 1 point width outline.
    ///   - scaleFactor: The scale factor used to calculate the `OverviewMap`'s scale.
    ///   The default is `25.0`.
    public init(
        proxy: GeoViewProxy?,
        map: Map = Map(basemap: Basemap.topographic()),
        extentSymbol: FillSymbol = SimpleFillSymbol(
            style: .solid,
            color: .clear,
            outline: SimpleLineSymbol(
                style: .solid,
                color: .red,
                width: 1.0
            )
        ),
        scaleFactor: Double = 25.0
    ) {
        self.proxy = proxy
        self.map = map
        self.extentSymbol = extentSymbol
        self.scaleFactor = scaleFactor
    }
    
    private var viewpointChangedPublisher: AnyPublisher<Void, Never> {
        proxy?.viewpointChangedPublisher
            .receive(on: DispatchQueue.main)
            .throttle(
                for: .seconds(0.25),
                scheduler: DispatchQueue.main,
                latest: true
            )
            .eraseToAnyPublisher() ?? Empty<Void, Never>().eraseToAnyPublisher()
    }

    public var body: some View {
        ZStack {
            MapView(
                map: map,
                viewpoint: $overviewMapViewpoint,
                graphicsOverlays: [GraphicsOverlay(
                                    graphics: [Graphic(geometry: extentGeometry,
                                                       symbol: extentSymbol)])]
            )
            .attributionTextHidden()
            .interactionModes([])
            .border(Color.black, width: 1)
            .onReceive(viewpointChangedPublisher) {
                guard let centerAndScaleViewpoint = proxy?.currentViewpoint(type: .centerAndScale),
                      let newCenter = centerAndScaleViewpoint.targetGeometry as? Point
                else { return }
                
                if let mapViewProxy = proxy as? MapViewProxy {
                    extentGeometry = mapViewProxy.visibleArea
                }
                
                overviewMapViewpoint = Viewpoint(
                    center: newCenter,
                    scale: centerAndScaleViewpoint.targetScale * scaleFactor)
            }
        }
    }
}
