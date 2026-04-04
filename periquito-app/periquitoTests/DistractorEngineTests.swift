import Testing
@testable import periquito

struct DistractorEngineTests {
    @Test("Parses correction tips into wrong, right and why components")
    func parsesCorrectionTip() {
        let parsed = DistractorEngine.parseTip("❌ I am agree → ✅ I agree — adjective pattern")

        #expect(parsed.wrong == "I am agree")
        #expect(parsed.right == "I agree")
        #expect(parsed.why == "adjective pattern")
    }

    @Test("Keeps the first correction variant when slash-separated alternatives are present")
    func keepsPrimaryCorrectionVariant() {
        let parsed = DistractorEngine.parseTip("❌ He go → ✅ He goes / He's going — subject-verb agreement")

        #expect(parsed.wrong == "He go")
        #expect(parsed.right == "He goes")
        #expect(parsed.why == "subject-verb agreement")
    }
}
