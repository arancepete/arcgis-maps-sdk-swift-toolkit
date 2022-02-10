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

import SwiftUI
import ArcGIS

/// The `FloorFilter` component simplifies visualization of GIS data for a specific floor of a building
/// in your application. It allows you to filter the floor plan data displayed in your map or scene view
/// to a site, a facility (building) in the site, or a floor in the facility.
public struct FloorFilter: View {
    /// Creates a `FloorFilter`
    /// - Parameters:
    ///   - floorManager: The floor manager used by the `FloorFilter`.
    ///   - viewpoint: Viewpoint updated when the selected site or facility changes.
    public init(
        floorManager: FloorManager,
        viewpoint: Binding<Viewpoint>? = nil
    ) {
        self.floorManager = floorManager
        self.viewpoint = viewpoint
    }
    
    let floorManager: FloorManager
    let viewpoint: Binding<Viewpoint>?
    
    /// The view model used by the `FloorFilter`.
    @StateObject
    private var viewModel = FloorFilterViewModel()
    
    /// Allows the user to toggle the visibility of the site selector.
    @State
    private var isSelectorVisible: Bool = false
    
    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .esriBorder()
            } else {
                HStack(alignment: .bottom) {
                    Button {
                        isSelectorVisible.toggle()
                    } label: {
                        Image("Site", bundle: .module, label: Text("Site"))
                    }
                    .esriBorder()
                    if isSelectorVisible {
                        SiteAndFacilitySelector(
                            floorFilterViewModel: viewModel,
                            isVisible: $isSelectorVisible
                        )
                            .frame(width: 200)
                    }
                }
            }
        }
        .onAppear {
            viewModel.floorManager = floorManager
            viewModel.viewpoint = viewpoint
        }
    }
}
