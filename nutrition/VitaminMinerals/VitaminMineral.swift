import Foundation

class VitaminMineralMgr: ObservableObject {


    init() {
    }


    // Returns the list of vitamin/mineral entries for the given
    // age/gender.  Pure function — no @Published mutation, so it's
    // safe to call from a view body without triggering the
    // "Publishing changes from within view updates" SwiftUI loop.
    //
    // Each entry's `id` is derived from the nutrient type so that
    // re-renders return objects with stable identity — this is what
    // keeps NavigationLink in the list from auto-popping when its
    // destination view (e.g., the Contributors drill-down) mutates
    // any shared @Published state.
    func getAll(age: Double, gender: Gender) -> [VitaminMineral] {
        return vitaminMineralOrder.map { type in
            VitaminMineral(id: String(describing: type), name: type, age: age, gender: gender)
        }
    }
}


struct VitaminMineral: Codable, Identifiable {
    var id: String
    var name: VitaminMineralType
    var age: Double
    var gender: Gender
    // var unit: Unit


    init(id: String = UUID().uuidString, name: VitaminMineralType, age: Double, gender: Gender) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
    }


    // The kebab-case nutrient key used in rda.yaml (and by
    // ConfigStore.shared.rda()) for each VitaminMineralType case.
    private static let kebabKey: [VitaminMineralType: String] = [
        .calcium: "calcium",
        .copper: "copper",
        .folate: "folate",
        .folicAcid: "folic-acid",
        .iron: "iron",
        .magnesium: "magnesium",
        .manganese: "manganese",
        .niacin: "niacin",
        .pantothenicAcid: "pantothenic-acid",
        .phosphorus: "phosphorus",
        .potassium: "potassium",
        .riboflavin: "riboflavin",
        .selenium: "selenium",
        .thiamin: "thiamin",
        .vitaminA: "vitamin-a",
        .vitaminB12: "vitamin-b12",
        .vitaminB6: "vitamin-b6",
        .vitaminC: "vitamin-c",
        .vitaminD: "vitamin-d",
        .vitaminE: "vitamin-e",
        .vitaminK: "vitamin-k",
        .zinc: "zinc",
    ]


    // Walk a config RDA/UL threshold list and return the value for
    // this entry's age/gender.  First row whose `age <= maxAge`
    // wins, picking the male/female column — identical lookup
    // semantics to the former hardcoded if-ladders.  Missing
    // nutrient/threshold returns 0.
    private func lookup(_ thresholds: [ConfigRDAThreshold]) -> Double {
        // NIH bands use whole-year ceilings (e.g. 14–18), so compare
        // the whole-year age: a continuous 18.5 must still land in the
        // 14–18 band, not fall through to the next one a year early.
        for row in thresholds where floor(age) <= row.maxAge {
            return gender == Gender.male ? row.male : row.female
        }
        return 0
    }


    func min() -> Double {
        guard let key = VitaminMineral.kebabKey[name],
              let rda = ConfigStore.shared.rda()[key] else { return 0 }
        return lookup(rda.min)
    }


    // The unit that min(), max(), and the per-nutrient totals
    // returned by computeVitaminMineralActuals are expressed in.
    // NIH publishes copper, folate/folic acid, selenium, vitamin A,
    // B12, and K in micrograms; vitamin D in International Units;
    // everything else in milligrams.  computeVitaminMineralActuals
    // converts ingredient field values into this unit so the row
    // comparison (min ≤ actual ≤ max) is unit-consistent.
    func unit() -> Unit {
        switch name {
        case .copper, .folate, .folicAcid, .selenium,
             .vitaminA, .vitaminB12, .vitaminK:
            return .microgram
        case .vitaminD:
            return .internationalUnit
        default:
            return .milligram
        }
    }


    func max() -> Double {
        guard let key = VitaminMineral.kebabKey[name],
              let rda = ConfigStore.shared.rda()[key] else { return 0 }
        return lookup(rda.max)
    }
}
