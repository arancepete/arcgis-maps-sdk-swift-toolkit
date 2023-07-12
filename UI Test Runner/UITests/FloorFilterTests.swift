// Copyright 2023 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

final class FloorFilterTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    /// Test general usage of the Floor Filter component.
    func testFloorFilter() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Open the Floor Filter component test view.
        app.buttons["Floor Filter Tests"].tap()
        
        // Wait for floor aware data to load and then open the filter.
        let filterButton = app.buttons["Business"]
        _ = filterButton.waitForExistence(timeout: 5)
        filterButton.tap()
        
        // Select the site named "Research Annex".
        app.buttons["Research Annex"].tap()
        
        // Select the facility named "Lattice".
        app.staticTexts["Lattice"].tap()
        
        // Select the level labeled "8".
        app.scrollViews.otherElements.staticTexts["8"].tap()
        
        let levelOneButton = app.staticTexts["1"]
        
        // Verify that the level selector is not collapsed
        // and other levels are available for selection.
        XCTAssertTrue(levelOneButton.exists)
        
        // Collapse the level selector.
        app.buttons["Go Down"].tap()
        
        // Verify that the level selector is collapsed.
        XCTAssertFalse(levelOneButton.exists)
    }
}
