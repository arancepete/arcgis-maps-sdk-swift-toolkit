import ArcGIS
import ArcGISToolkit
import SwiftUI

struct ScalebarExampleView: View {
    @State private var spatialReference: SpatialReference?
    
    @State private var unitsPerPoint: Double?
    
    @State private var viewpoint: Viewpoint?
    
    private let alignment: Alignment = .bottomLeading
    
    @State private var map = Map(basemapStyle: .arcGISTopographic)
    
    private let maxWidth: Double = 175.0
    
    var body: some View {
        MapView(map: map)
            .onSpatialReferenceChanged { spatialReference = $0 }
            .onUnitsPerPointChanged { unitsPerPoint = $0 }
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
    }
}
