import Foundation

// ============================================================
// Result of a label scan, decoded straight from Anthropic's
// tool_use input. Mirrors the JSON schema in
// NutritionScannerService.toolDefinition.
//
// Every nutrition field is optional — labels show different
// subsets, and a missing value should mean "don't overwrite the
// existing value on update / leave the form blank on add", not
// "the value is zero".
// ============================================================
struct ParsedIngredient: Codable, Equatable {

    // What the LLM thinks should happen with this scan.
    let match: ParsedMatch

    // Identity / product details
    let name: String
    let brand: String?
    let fullName: String?
    let url: String?
    let ingredientsList: [String]?
    let allergens: [String]?

    // Serving + consumption
    let servingSize: Double?           // grams per serving
    let consumptionUnit: String?       // matches Unit enum case names
    let consumptionGrams: Double?

    // Pricing (populated by the AI verify-by-name flow; nil from a
    // plain label scan). price → Ingredient.totalCost,
    // packageGrams → Ingredient.totalGrams. Web-sourced price is
    // always region/time-approximate, so it's always returned in
    // lowConfidenceFields and never auto-applied.
    let price: Double?
    let packageGrams: Double?

    // Macros
    let calories: Double?
    let fat: Double?
    let saturatedFat: Double?
    let transFat: Double?
    let cholesterol: Double?
    let sodium: Double?
    let carbohydrates: Double?
    let fiber: Double?
    let sugar: Double?
    let addedSugar: Double?
    let netCarbs: Double?
    let protein: Double?

    // Vitamins & minerals (matches Ingredient field names exactly;
    // each has a `parsed:` keypath row in NutrientCatalog, which
    // drives the tool schema, ScanDiff, and the prefill loops)
    let omega3: Double?
    let vitaminD: Double?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminE: Double?
    let vitaminK: Double?
    let thiamin: Double?
    let riboflavin: Double?
    let niacin: Double?
    let vitaminB6: Double?
    let folate: Double?
    let vitaminB12: Double?
    let pantothenicAcid: Double?
    let phosphorus: Double?
    let magnesium: Double?
    let zinc: Double?
    let selenium: Double?
    let copper: Double?
    let manganese: Double?

    // Names of any of the above fields the model is unsure about.
    // Used to tint the form rows yellow during review.
    let lowConfidenceFields: [String]


    // Map the LLM's enum string back to our Swift Unit. Anything
    // unrecognized (or nil) collapses to .gram, which is the most
    // common consumption unit and a safe default the user can change.
    var consumptionUnitEnum: Unit {
        switch consumptionUnit {
        case "tablespoon": return .tablespoon
        case "cup":        return .cup
        case "piece":      return .piece
        case "egg":        return .egg
        case "slice":      return .slice
        case "can":        return .can
        case "bar":        return .bar
        case "whole":      return .whole
        case "pill":       return .pill
        case "gram", nil:  return .gram
        default:           return .gram
        }
    }
}


// ============================================================
// What the LLM wants us to do with this scan.
// Decoded from a tagged-union JSON shape:
//   {"kind":"new"}
//   {"kind":"update","name":"Chicken"}
//   {"kind":"ambiguous","candidates":["Chicken","Chicken Thigh"]}
// ============================================================
enum ParsedMatch: Codable, Equatable {
    case new
    case update(name: String)
    case ambiguous(candidates: [String])


    private enum CodingKeys: String, CodingKey {
        case kind, name, candidates
    }


    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "new":
            self = .new
        case "update":
            // The tool schema only requires `kind`, so `name` can be
            // missing. Losing the match target is recoverable as a
            // new-ingredient flow; throwing would lose the whole scan.
            let name = try c.decodeIfPresent(String.self, forKey: .name)
            if let name = name, !name.isEmpty {
                self = .update(name: name)
            } else {
                self = .new
            }
        case "ambiguous":
            // Same recovery: no candidates to choose from means the
            // scan can only proceed as a new ingredient.
            let candidates = try c.decodeIfPresent([String].self, forKey: .candidates)
            if let candidates = candidates, !candidates.isEmpty {
                self = .ambiguous(candidates: candidates)
            } else {
                self = .new
            }
        default:
            // Unknown kinds default to .new — safer than throwing,
            // since a parse error here would lose the whole scan.
            self = .new
        }
    }


    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .new:
            try c.encode("new", forKey: .kind)
        case .update(let name):
            try c.encode("update", forKey: .kind)
            try c.encode(name, forKey: .name)
        case .ambiguous(let candidates):
            try c.encode("ambiguous", forKey: .kind)
            try c.encode(candidates, forKey: .candidates)
        }
    }
}
