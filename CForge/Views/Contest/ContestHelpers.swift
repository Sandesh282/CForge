import SwiftUI

extension ContestListView {
    var filteredContests: [CFContest] {
        contests
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.startTime < $1.startTime }
    }
}
