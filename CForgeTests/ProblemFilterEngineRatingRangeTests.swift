import Testing
@testable import CForge

struct ProblemFilterEngineRatingRangeTests {
    
    @Test func filterReturnsAllWhenRangeIsNil() {
        let problems = [
            makeProblem(id: "rated", rating: 1000),
            makeProblem(id: "unrated", rating: nil)
        ]
        
        let filtered = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: nil
        )
        
        #expect(filtered == problems)
    }
    
    @Test func filterDropsNilRatedProblemsWhenRangeIsActive() {
        let problems = [
            makeProblem(id: "rated", rating: 1100),
            makeProblem(id: "unrated", rating: nil)
        ]
        
        let filtered = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1000to1200
        )
        
        #expect(filtered.map { $0.id } == ["rated"])
    }
    
    @Test func filterKeepsProblemsInRange() {
        let problems = [
            makeProblem(id: "in-range", rating: 1100),
            makeProblem(id: "out-of-range", rating: 800)
        ]
        
        let filtered = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1000to1200
        )
        
        #expect(filtered.map { $0.id } == ["in-range"])
    }
    
    @Test func filterIncludesHighRatingsInR1800Plus() {
        let problems = [
            makeProblem(id: "gm-level", rating: 3500),
            makeProblem(id: "below", rating: 1799)
        ]
        
        let filtered = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1800Plus
        )
        
        #expect(filtered.map { $0.id } == ["gm-level"])
    }
    
    @Test func filterIncludesInclusiveLowerBound() {
        let problems = [makeProblem(id: "lower", rating: 1000)]
        
        let filtered = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1000to1200
        )
        
        #expect(filtered.map { $0.id } == ["lower"])
    }
    
    @Test func filterExcludesUpperBound() {
        let problems = [
            makeProblem(id: "upper-excluded", rating: 1200),
            makeProblem(id: "upper-included-elsewhere", rating: 1200)
        ]
        
        let inLow = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1000to1200
        )
        
        #expect(inLow.isEmpty)
        
        let inHigh = ProblemFilterEngine.filter(
            problems: problems,
            query: "",
            selectedTag: nil,
            ratingRange: .r1200to1400
        )
        
        #expect(inHigh.count == 2)
    }
    
    private func makeProblem(id: String, rating: Int?) -> Problem {
        Problem(
            id: id,
            contestId: 1,
            index: id,
            title: "Problem \(id)",
            rating: rating,
            tags: []
        )
    }
}
