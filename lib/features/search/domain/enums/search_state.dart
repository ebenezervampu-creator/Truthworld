/// SearchState: UI state representation
enum SearchState {
  idle,     // Initial state, show recent searches
  loading,  // Fetching data, show skeletons
  results,  // Data received, show list
  empty,    // No results found
  error     // Something went wrong
}
