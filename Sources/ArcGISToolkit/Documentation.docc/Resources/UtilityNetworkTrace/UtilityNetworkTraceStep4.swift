import ArcGIS
import ArcGISToolkit
import SwiftUI

struct UtilityNetworkTraceExampleView: View {
    @State private var map = makeMap()
    
    @State var mapPoint: Point?
    
    @State var screenPoint: CGPoint?
    
    @State var resultGraphicsOverlay = GraphicsOverlay()
    
    @State var viewpoint: Viewpoint?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(
                map: map,
                viewpoint: viewpoint,
                graphicsOverlays: [resultGraphicsOverlay]
            )
            .onSingleTapGesture { screenPoint, mapPoint in
                self.screenPoint = screenPoint
                self.mapPoint = mapPoint
            }
            .onViewpointChanged(kind: .centerAndScale) {
                viewpoint = $0
            }
            .task {
                let publicSample = try? await ArcGISCredential.publicSample
                ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(publicSample!)
            }
        }
    }
}
