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

import ArcGIS

/// Wraps a suggestion for display.
public class SearchSuggestion {
    internal init(displayTitle: String,
                  displaySubtitle: String? = nil,
                  owningSource: SearchSourceProtocol,
                  suggestResult: SuggestResult? = nil,
                  isCollection: Bool) {
        self.displayTitle = displayTitle
        self.displaySubtitle = displaySubtitle
        self.owningSource = owningSource
        self.suggestResult = suggestResult
        self.isCollection = isCollection
    }
    
    /// Title that should be used when displaying a suggestion.
    var displayTitle: String
    
    /// Optional subtitle that can be displayed when showing a suggestion.
    var displaySubtitle: String?
    
    /// Reference to the `SearchSourceProtocol` that created this suggestion. This property is necessary for the
    /// view model to be able to accept a suggestion, because a suggestion should only be used with the
    /// locator that created it.
    var owningSource: SearchSourceProtocol
    
    /// Underlying suggest result if this suggestion was created by a LocatorTask. This can be `nil`, and
    /// is likely to be `nil` when using custom `SearchSourceProtocol` implementations.
    var suggestResult: SuggestResult?
    
    /// True if the search from this suggestion should be treated like a collection search, false if the
    /// search would return a single result. This property should be used to display a different icon
    /// in the UI depending on if this is a category search (like 'Coffee', 'Pizza', or 'Starbucks') and
    /// false if it is a search for a specific result (e.g. '380 New York St. Redlands CA').
    var isCollection: Bool
}

extension SearchSuggestion: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

extension SearchSuggestion: Equatable {
    public static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

extension SearchSuggestion: Hashable {
    /// Note:  we're not hashing `suggestResult` as `SearchSuggestion` is created from
    /// a `SuggestResult` and `suggestResult` will be different for two sepate geocode
    /// operations even though they represent the same suggestion.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayTitle)
        hasher.combine(displaySubtitle)
        hasher.combine(isCollection)

        if let locatorSource = owningSource as? LocatorSearchSource {
            hasher.combine(ObjectIdentifier(locatorSource))
        }
        // If you define a custom type that does NOT inherit from
        // `LocatorSearchSource`, you will need to add an `else if` check
        // for your custom type.
//        else if let customSearchSource = owningSource as? MyCustomSearchSource {
//            hasher.combine(ObjectIdentifier(customSearchSource))
//        }
    }
}
