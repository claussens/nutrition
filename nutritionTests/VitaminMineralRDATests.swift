import XCTest
@testable import Nutrition


// Characterization of the RDA band lookup (VitaminMineral.min/max
// via the rda.yaml thresholds): first row whose age fits wins, and
// the comparison uses the WHOLE-YEAR age (floor), so a continuous
// 18.5 still lands in the NIH 14–18 band instead of falling through
// to the adult band a year early.
//
// These run against the app's real rda.yaml (loaded by the test
// host), so they also pin the current calcium band values.
final class VitaminMineralRDATests: XCTestCase {

    override func setUp() {
        super.setUp()
        // The test host normally loads the config at launch; make
        // sure it's there when tests run in isolation.
        if ConfigStore.shared.rda().isEmpty {
            ConfigStore.shared.loadInitial()
        }
        XCTAssertFalse(ConfigStore.shared.rda().isEmpty, "rda.yaml failed to load in the test host")
    }

    private func calcium(age: Double, gender: Gender = .male) -> VitaminMineral {
        VitaminMineral(name: .calcium, age: age, gender: gender)
    }

    func testWholeYearAgeKeepsEighteenPointFiveInTeenBand() {
        // floor(18.5) = 18 ≤ 18 → the 14–18 band (1300), NOT the
        // 19–50 adult band (1000).
        XCTAssertEqual(calcium(age: 18.5).min(), 1300)
        XCTAssertEqual(calcium(age: 18.5).max(), 3000)
    }

    func testNineteenGetsAdultBand() {
        XCTAssertEqual(calcium(age: 19.0).min(), 1000)
        XCTAssertEqual(calcium(age: 19.0).max(), 2500)
    }

    func testFirstMatchingBandWins() {
        // 13.9 → floor 13 ≤ 13 → the 9–13 band, even though the
        // 14–18 row would also satisfy the ≤ comparison.
        XCTAssertEqual(calcium(age: 13.9).min(), 1300)
        XCTAssertEqual(calcium(age: 8.9).min(), 1000)
    }

    func testGenderColumnSelection() {
        // Calcium 51–70: male 1000 vs female 1200.
        XCTAssertEqual(calcium(age: 60, gender: .male).min(), 1000)
        XCTAssertEqual(calcium(age: 60, gender: .female).min(), 1200)
    }

    func testInfinityBandCatchesEveryone() {
        // Over the last finite ceiling (70): the .inf row applies.
        XCTAssertEqual(calcium(age: 84, gender: .male).min(), 1200)
        XCTAssertEqual(calcium(age: 84, gender: .male).max(), 2000)
    }

    func testUnitMapping() {
        XCTAssertEqual(VitaminMineral(name: .calcium, age: 40, gender: .male).unit(), .milligram)
        XCTAssertEqual(VitaminMineral(name: .copper, age: 40, gender: .male).unit(), .microgram)
        XCTAssertEqual(VitaminMineral(name: .vitaminD, age: 40, gender: .male).unit(), .internationalUnit)
    }
}
