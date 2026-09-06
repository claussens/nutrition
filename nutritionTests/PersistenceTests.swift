import XCTest
@testable import Nutrition


// Persistence edges that used to lose data silently: a history file
// that no longer decodes, a meal the user emptied on purpose, and the
// theme colors the whole UI is painted with.
final class PersistenceTests: XCTestCase {

    private func scratchURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("zzztest-\(UUID().uuidString)-\(name)")
    }

    func testCorruptHistoryIsMovedAsideNotOverwritten() throws {
        let url = scratchURL("daylog.json")
        try Data("not json".utf8).write(to: url)

        let mgr = DayLogMgr(activeProfileId: "p", fileURL: url)
        XCTAssertTrue(mgr.logs.isEmpty)

        // The unreadable file survives under a .corrupt.json name and the
        // live path is free for the next Log Today.
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertEqual(try String(contentsOf: backup), "not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        mgr.logToday(profileId: "p", entries: [],
                     totals: DayLogTotals(calories: 1, fat: 0, fiber: 0, netCarbs: 0, protein: 0, cost: 0),
                     vitamins: [], body: DayLogBody(weightLbs: nil, age: nil, activeEnergy: nil))
        XCTAssertEqual(DayLogMgr(activeProfileId: "p", fileURL: url).logs.count, 1)
        XCTAssertEqual(try String(contentsOf: backup), "not json")
    }

    func testMissingHistoryStartsEmpty() {
        XCTAssertTrue(DayLogMgr(activeProfileId: "p", fileURL: scratchURL("none.json")).logs.isEmpty)
    }

    func testEmptiedMealStaysEmptyAcrossReload() {
        let pid = "zzztest-" + UUID().uuidString
        let m = MealIngredientMgr(profileId: pid, profileName: pid)
        m.create(name: "Cheese", amount: 1)
        m.delete(m.mealIngredients[0])
        XCTAssertTrue(m.mealIngredients.isEmpty)

        // A saved empty meal must not be mistaken for "never saved" and
        // reseeded from config.
        let again = MealIngredientMgr(profileId: pid, profileName: pid)
        XCTAssertTrue(again.mealIngredients.isEmpty)
        UserDefaults.standard.removeObject(forKey: "mealIngredient.\(pid)")
    }

    func testEveryThemeColorHasAColorset() {
        // ColorTheme names a colorset per property; a missing one renders
        // clear and only shows up on the phone.
        for name in ["BlackWhite", "BlackWhiteSecondary", "BlueYellow", "BlueYellowSecondary",
                     "Manual", "ProgressLineBackground", "Black", "Blue", "Green", "Yellow", "Red"] {
            XCTAssertNotNil(UIColor(named: name, in: Bundle(for: MealIngredientMgr.self), compatibleWith: nil),
                            "no colorset named \(name) in the app bundle")
        }
    }
}
