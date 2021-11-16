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

import Swift
import SwiftUI
import ArcGIS
import Combine

/// Performs searches and manages search state for a Search, or optionally without a UI connection.
@MainActor
public class SearchViewModel: ObservableObject {
    /// Defines how many results to return; one, many, or automatic based on circumstance.
    public enum SearchResultMode {
        /// Search should always result in at most one result.
        case single
        /// Search should always try to return multiple results.
        case multiple
        /// Search should make a choice based on context. E.g. 'coffee shop' should be multiple results,
        /// while '380 New York St. Redlands' should be one result.
        case automatic
    }
    
    /// The outcome of a geocode operation (search or suggestion).
    public enum SearchOutcome {
        case results(result: Result<[SearchResult], SearchError>)
        case suggestions(result: Result<[SearchSuggestion], SearchError>)
    }
    
    /// Creates a `SearchViewModel`.
    /// - Parameters:
    ///   - activeSource: Tracks the currently active search source.
    ///   - queryArea: The search area to be used for the current query.
    ///   - queryCenter: Defines the center for the search.
    ///   - resultMode: Defines how many results to return.
    ///   - sources: Collection of search sources to be used.
    public init(
        activeSource: SearchSource? = nil,
        queryArea: Geometry? = nil,
        queryCenter: Point? = nil,
        resultMode: SearchResultMode = .automatic,
        sources: [SearchSource] = []
    ) {
        self.activeSource = activeSource
        self.queryArea = queryArea
        self.queryCenter = queryCenter
        self.resultMode = resultMode
        self.sources = sources
    }
    
    /// The active search source.  If `nil`, the first item in `sources` is used.
    public var activeSource: SearchSource?
    
    /// Tracks the current user-entered query. This property drives both suggestions and searches.
    @Published
    public var currentQuery: String = "" {
        willSet {
            isEligibleForRequery = false
            
            switch searchOutcome {
            case .results(_):
                searchOutcome = nil
            case .suggestions(_):
                if currentQuery.isEmpty {
                    searchOutcome = nil
                }
            case .none:
                break
            }
        }
    }
    
    /// The extent at the time of the last search.  This is primarily set by the model, but in certain
    /// circumstances can be set by an external client, for example after a view zooms programmatically
    /// to an extent based on results of a search.
    public var lastSearchExtent: Envelope? = nil {
        didSet {
            isEligibleForRequery = false
        }
    }
    
    /// The current map/scene view extent. Defaults to `nil`.
    ///
    /// This should be updated as the user navigates the map/scene. It will be
    /// used to determine the value of `isEligibleForRequery` for the 'Repeat
    /// search here' behavior. If that behavior is not wanted, it should be left `nil`.
    public var geoViewExtent: Envelope? = nil {
        willSet {
            guard !isEligibleForRequery,
                  !currentQuery.isEmpty,
                  let lastExtent = lastSearchExtent,
                  let newExtent = newValue
            else { return }
            
            // Check extent difference.
            let widthDiff = abs(lastExtent.width - newExtent.width)
            let heightDiff = abs(lastExtent.height - newExtent.height)
            
            let widthThreshold = lastExtent.width * 0.25
            let heightThreshold = lastExtent.height * 0.25
            
            isEligibleForRequery = widthDiff > widthThreshold || heightDiff > heightThreshold
            guard !isEligibleForRequery else { return }
            
            // Check center difference.
            let centerDiff = GeometryEngine.distance(
                geometry1: lastExtent.center,
                geometry2: newExtent.center
            )
            let currentExtentAvg = (lastExtent.width + lastExtent.height) / 2.0
            let threshold = currentExtentAvg * 0.25
            isEligibleForRequery = (centerDiff ?? 0.0) > threshold
        }
    }
    
    /// `true` if the extent has changed by a set amount after a `Search` or `AcceptSuggestion` call.
    /// This property is used by the view to enable 'Repeat search here' functionality. This property is
    /// observable, and the view should use it to hide and show the 'repeat search' button.
    /// Changes to this property are driven by changes to the `geoViewExtent` property.  This value will be
    /// true if the extent center changes by more than 25% of the average of the extent's height and width
    /// at the time of the last search or if the extent width/height changes by the same amount.
    @Published
    public private(set) var isEligibleForRequery: Bool = false
    
    /// The search area to be used for the current query. Results will be limited to those
    /// within `QueryArea`.  Defaults to `nil`.
    public var queryArea: Geometry? = nil
    
    /// Defines the center for the search. For most use cases, this should be updated by the view
    /// every time the user navigates the map.
    public var queryCenter: Point?
    
    /// Defines how many results to return. Defaults to Automatic. In automatic mode, an appropriate
    /// number of results is returned based on the type of suggestion chosen
    /// (driven by the `isCollection` property).
    public var resultMode: SearchResultMode = .automatic
    
    /// Collection of results. `nil` means no query has been made. An empty array means there
    /// were no results, and the view should show an appropriate 'no results' message.
    ///
    /// Collection of suggestion results. Defaults to `nil`. This collection will be set to empty when there
    /// are no suggestions, `nil` when no suggestions have been requested. If the list is empty,
    /// a useful 'no results' message should be shown by the view.
    
    @Published
    public private(set) var searchOutcome: SearchOutcome? {
        didSet {
            switch searchOutcome {
            case .results(let results):
                switch results {
                case .success(let results):
                    if results.count == 1 {
                        selectedResult = results.first
                    }
                    else {
                        selectedResult = nil
                    }
                default:
                    selectedResult = nil
                }
            default:
                selectedResult = nil
                break
            }
        }
    }
    
    /// Tracks selection of results from the `results` collection. When there is only one result,
    /// that result is automatically assigned to this property. If there are multiple results, the view sets
    /// this property upon user selection. This property is observable. The view should observe this
    /// property and update the associated GeoView's viewpoint, if configured.
    @Published
    public var selectedResult: SearchResult?
    
    /// Collection of search sources to be used. This list is maintained over time and is not nullable.
    /// The view should observe this list for changes. Consumers should add and remove sources from
    /// this list as needed.
    /// NOTE:  only the first source is currently used; multiple sources are not yet supported.
    public var sources: [SearchSource] = []
    
    /// The currently executing async task.  `currentTask` should be cancelled
    /// prior to starting another async task.
    private var currentTask: Task<Void, Never>?
    
    /// Starts a search. `selectedResult` and `results`, among other properties, are set
    /// asynchronously. Other query properties are read to define the parameters of the search.
    public func commitSearch() {
        kickoffTask({ searchTask() })
    }
    
    /// Repeats the last search, limiting results to the extent specified in `geoViewExtent`.
    public func repeatSearch() {
        kickoffTask({ repeatSearchTask() })
    }
    
    /// Updates suggestions list asynchronously.
    public func updateSuggestions() {
        guard currentSuggestion == nil else {
            // don't update suggestions if currently searching for one
            return
        }
        
        kickoffTask({ updateSuggestionsTask() })
    }
    
    @Published
    public var currentSuggestion: SearchSuggestion? {
        didSet {
            if let currentSuggestion = currentSuggestion {
                acceptSuggestion(currentSuggestion)
            }
        }
    }
    
    /// Commits a search from a specific suggestion. Results will be set asynchronously. Behavior is
    /// generally the same as `commitSearch`, except `searchSuggestion` is used instead of the
    /// `currentQuery` property.
    /// - Parameters:
    ///   - searchSuggestion: The suggestion to use to commit the search.
    public func acceptSuggestion(_ searchSuggestion: SearchSuggestion) {
        currentQuery = searchSuggestion.displayTitle
        kickoffTask({ acceptSuggestionTask(searchSuggestion) })
    }
    
    private func kickoffTask(_ taskInit: () -> Task<(), Never>) {
        currentTask?.cancel()
        currentTask = taskInit()
    }
}

private extension SearchViewModel {
    func repeatSearchTask() -> Task<(), Never> {
        Task {
            guard !currentQuery.trimmingCharacters(in: .whitespaces).isEmpty,
                  let queryExtent = geoViewExtent,
                  let source = currentSource() else {
                      return
                  }
            
            await search(with: {
                try await source.repeatSearch(
                    currentQuery,
                    searchExtent: queryExtent
                )
            } )
        }
    }
    
    func searchTask() -> Task<(), Never> {
        Task {
            guard !currentQuery.trimmingCharacters(in: .whitespaces).isEmpty,
                  let source = currentSource() else { return }
            
            await search(with: {
                try await source.search(
                    currentQuery,
                    searchArea: queryArea,
                    preferredSearchLocation: queryCenter
                )
            } )
        }
    }
    
    func updateSuggestionsTask() -> Task<(), Never> {
        Task {
            guard !currentQuery.trimmingCharacters(in: .whitespaces).isEmpty,
                  let source = currentSource() else {
                      return
                  }
            do {
                let suggestions = try await source.suggest(
                    currentQuery,
                    searchArea: queryArea,
                    preferredSearchLocation: queryCenter
                )
                searchOutcome = .suggestions(result: .success(suggestions))
            } catch is CancellationError {
                searchOutcome = nil
            } catch {
                searchOutcome = .suggestions(result: .failure(SearchError(error)))
            }
        }
    }
    
    func acceptSuggestionTask(_ searchSuggestion: SearchSuggestion) -> Task<(), Never> {
        Task {
            await search(with: {
                try await searchSuggestion.owningSource.search(
                    searchSuggestion,
                    searchArea: queryArea,
                    preferredSearchLocation: queryCenter
                )
            } )
            
            // once we are done searching for the suggestion, then reset it to nil
            currentSuggestion = nil
        }
    }
    
    func search(with action: () async throws -> [SearchResult]) async {
        do {
            // User is performing a search, so set `lastSearchExtent`.
            lastSearchExtent = geoViewExtent
            try await process(searchResults: action())
        } catch is CancellationError {
            searchOutcome = nil
        } catch {
            searchOutcome = .results(result: .failure(SearchError(error)))
        }
    }
    
    func process(searchResults: [SearchResult], isCollection: Bool = true) {
        let effectiveResults: [SearchResult]
        
        switch resultMode {
        case .single:
            effectiveResults = Array(searchResults.prefix(1))
        case .multiple:
            effectiveResults = searchResults
        case .automatic:
            if isCollection {
                effectiveResults = searchResults
            } else {
                effectiveResults = Array(searchResults.prefix(1))
            }
        }
        
        searchOutcome = .results(result: .success(effectiveResults))
    }
}

extension SearchViewModel {
    /// Returns the search source to be used in geocode operations.
    /// - Returns: The search source to use.
    func currentSource() -> SearchSource? {
        let source: SearchSource?
        if let activeSource = activeSource {
            source = activeSource
        } else {
            source = sources.first
        }
        return source
    }
}

extension SearchViewModel.SearchOutcome: Equatable {}
