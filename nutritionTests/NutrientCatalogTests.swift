import XCTest
@testable import Nutrition

// ============================================================
// Drift tests for NutrientCatalog — the single descriptor table
// driving Ingredient Codable, the config kebab→camel bridge, the
// scanner schema, ScanDiff, the V&M forms, and the RDA lookups.
// Each test round-trips EVERY descriptor through one of those
// surfaces, so a nutrient added to one place but not another
// fails here instead of silently reading 0 at runtime.
// ============================================================
final class NutrientCatalogTests: XCTestCase {

    // ------------------------------------------------------------
    // Table invariants: ids and kebab keys are unique, and every
    // VitaminMineralType case is described by exactly one row.
    // ------------------------------------------------------------
    func testCatalogInvariants() {
        let ids = NutrientCatalog.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate descriptor id")

        let kebabs = NutrientCatalog.all.map { $0.kebabKey }
        XCTAssertEqual(Set(kebabs).count, kebabs.count, "duplicate kebab key")

        let vmTypes = NutrientCatalog.all.compactMap { $0.vmType }
        XCTAssertEqual(vmTypes.count, Set(vmTypes).count, "VitaminMineralType described twice")
        XCTAssertEqual(Set(vmTypes), Set(VitaminMineralType.allCases),
                       "every VitaminMineralType case needs a catalog row")

        // The historical spelling is a live JSON key — guard it.
        XCTAssertTrue(ids.contains("sugarAlcohool"))
    }


    // ------------------------------------------------------------
    // Config bridge: a ConfigIngredient carrying a distinct value
    // for every nutrient must surface each one on the decoded
    // runtime Ingredient via the descriptor's keypath.
    // ------------------------------------------------------------
    func testConfigBridgeRoundTripsEveryDescriptor() throws {
        var nutrients: [String: Double] = [:]
        var expected: [String: Double] = [:]
        for (i, d) in NutrientCatalog.inNutrientsMap.enumerated() {
            nutrients[d.kebabKey] = Double(i + 1)
            expected[d.id] = Double(i + 1)
        }
        // Core macros are top-level config fields, not nutrients-map
        // entries.
        expected["calories"] = 1001
        expected["fat"]      = 1002
        expected["fiber"]    = 1003
        expected["netCarbs"] = 1004
        expected["protein"]  = 1005

        let ci = ConfigIngredient(name: "RoundTrip",
                                  food: "RoundTrip",
                                  brand: nil,
                                  servingSize: 100,
                                  consumptionUnit: "gram",
                                  consumptionGrams: 1,
                                  calories: 1001,
                                  fat: 1002,
                                  fiber: 1003,
                                  netCarbs: 1004,
                                  protein: 1005,
                                  price: nil,
                                  url: nil,
                                  verified: nil,
                                  nutrients: nutrients)

        let dict = ConfigStore.shared.flatIngredientDict(from: ci)
        let json = try JSONSerialization.data(withJSONObject: dict)
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: json)

        for d in NutrientCatalog.all {
            XCTAssertEqual(ingredient[keyPath: d.ingredient], expected[d.id],
                           "config bridge dropped or misrouted '\(d.id)' (kebab '\(d.kebabKey)')")
        }
    }


    // ------------------------------------------------------------
    // Scanner + ScanDiff: JSON keyed by descriptor id (exactly what
    // the tool schema makes the model produce) must decode onto
    // ParsedIngredient's keypaths, show up as one Change per field
    // in compute(), and land on the Ingredient via apply().
    // ------------------------------------------------------------
    func testScanDiffRoundTripsEveryScannableDescriptor() throws {
        var input: [String: Any] = [
            "match": ["kind": "new"],
            "name": "RoundTrip",
            "lowConfidenceFields": [String]()
        ]
        var expected: [String: Double] = [:]
        for (i, d) in NutrientCatalog.scannable.enumerated() {
            input[d.id] = Double(i + 1)
            expected[d.id] = Double(i + 1)
        }

        let parsed = try JSONDecoder().decode(
            ParsedIngredient.self,
            from: JSONSerialization.data(withJSONObject: input))

        // Schema id ↔ ParsedIngredient property agreement.
        for d in NutrientCatalog.scannable {
            XCTAssertEqual(parsed[keyPath: d.parsed!], expected[d.id],
                           "schema id '\(d.id)' didn't decode onto ParsedIngredient")
        }

        // compute() emits exactly one Change per scannable nutrient
        // (identity fields match; serving/price fields are nil).
        var ingredient = Fixtures.ingredient(name: "RoundTrip", food: "")
        let diff = ScanDiff.compute(existing: ingredient, parsed: parsed)
        XCTAssertEqual(Set(diff.changes.map { $0.id }), Set(expected.keys))

        // apply() writes every accepted id through its keypath.
        ScanDiff.apply(parsed: parsed, ids: Set(expected.keys), to: &ingredient)
        for d in NutrientCatalog.scannable {
            XCTAssertEqual(ingredient[keyPath: d.ingredient], expected[d.id],
                           "apply() dropped '\(d.id)'")
        }
    }


    // ------------------------------------------------------------
    // The two unit conversions live in the catalog only: copper is
    // stored mg / reported mcg (×1000), vitamin D stored mcg /
    // reported IU (×40); everything else passes through unchanged.
    // ------------------------------------------------------------
    func testRDAUnitConversions() {
        var ingredient = Fixtures.ingredient(name: "Units", food: "")
        ingredient.copper = 2        // mg
        ingredient.vitaminD = 10     // mcg
        ingredient.calcium = 500     // mg

        XCTAssertEqual(nutrientValue(of: ingredient, for: .copper), 2000)   // mcg
        XCTAssertEqual(nutrientValue(of: ingredient, for: .vitaminD), 400)  // IU
        XCTAssertEqual(nutrientValue(of: ingredient, for: .calcium), 500)   // mg

        XCTAssertEqual(VitaminMineral(name: .copper, age: 40, gender: .male).unit(), .microgram)
        XCTAssertEqual(VitaminMineral(name: .vitaminD, age: 40, gender: .male).unit(), .internationalUnit)
        XCTAssertEqual(VitaminMineral(name: .calcium, age: 40, gender: .male).unit(), .milligram)
    }


    // ------------------------------------------------------------
    // Derived orders match the historical hand-maintained lists.
    // ------------------------------------------------------------
    func testDerivedOrdersMatchHistoricalLists() {
        XCTAssertEqual(vitaminMineralOrder, [
            .calcium, .copper, .folate, .folicAcid, .iron, .magnesium,
            .manganese, .niacin, .pantothenicAcid, .phosphorus, .potassium,
            .riboflavin, .selenium, .thiamin, .vitaminA, .vitaminB12,
            .vitaminB6, .vitaminC, .vitaminD, .vitaminE, .vitaminK, .zinc
        ])

        XCTAssertEqual(NutrientCatalog.vmFormRows.map { $0.id }, [
            "omega3", "vitaminD", "calcium", "iron", "potassium",
            "vitaminA", "vitaminC", "vitaminE", "vitaminK", "thiamin",
            "vitaminB6", "folate", "vitaminB12", "pantothenicAcid",
            "phosphorus", "magnesium", "zinc", "selenium", "copper",
            "manganese", "niacin", "riboflavin"
        ])
    }
}
