import Testing
@testable import periquito

struct ParrotLevelTests {
    @Test("Promotes to the highest level that matches XP and accuracy")
    func promotesToHighestQualifiedLevel() {
        let level = ParrotLevel.levelFor(xp: 2_500, accuracy: 72, currentLevel: .egg)

        #expect(level == .macaw)
    }

    @Test("Does not downgrade when current level is already higher")
    func doesNotDowngradeCurrentLevel() {
        let level = ParrotLevel.levelFor(xp: 0, accuracy: 0, currentLevel: .phoenix)

        #expect(level == .phoenix)
    }

    @Test("Blocks promotion when accuracy is below the next threshold")
    func requiresAccuracyToLevelUp() {
        let level = ParrotLevel.levelFor(xp: 5_000, accuracy: 60, currentLevel: .parrot)

        #expect(level == .parrot)
    }
}
