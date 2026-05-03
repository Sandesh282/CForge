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
