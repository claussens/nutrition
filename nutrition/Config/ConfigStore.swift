import Foundation
import Yams   // SPM dependency, added by the orchestrator.

// ============================================================================
// ConfigStore — the app's single in-memory home for the parsed config data set
// ============================================================================
//
// ConfigStore owns the decoded `ConfigData` (the five YAML files: food,
// ingredients, meals, supplements, rda) and is the bridge between the wire
// types in ConfigModels.swift and the runtime model types the rest of the app
// consumes (`Food`, `Ingredient`, `ConfigMealRow`, `ConfigSupplement`,
// `ConfigRDA`).
//
// Lifecycle:
//   • `loadInitial()` is called once at launch. It loads the LAST SUCCESSFUL
//     refresh from the app's Documents directory if present, otherwise falls
//     back to the YAML copies bundled in the app. Either way it parses all five
//     files with Yams into a `ConfigData` and publishes it on `data`.
//   • `apply(_:)` is called by ConfigSync after a successful GitHub refresh. It
//     atomically persists the five YAML strings to Documents and swaps `data`.
//
// Persistence model: we cache the RAW YAML TEXT (one file per section) in
// Documents. That keeps round-tripping lossless and side-steps any YAMLEncoder
// key-ordering / formatting drift. `apply(_:)` re-encodes `ConfigData` back to
// YAML via Yams so the on-disk cache always reflects exactly what's live.
//
// Change detection: per-file blob shas live in UserDefaults; ConfigSync reads
// them (`cachedShas()`) to short-circuit unchanged refreshes and writes them
// (`saveShas(_:)`) after a successful apply.

final class ConfigStore: ObservableObject {

    static let shared = ConfigStore()

    /// The live, parsed config. `nil` until `loadInitial()` runs.
    @Published private(set) var data: ConfigData? = nil

    private init() {}

    // ------------------------------------------------------------------------
    // Filenames — one per config section. These match both the bundled copies
    // (Config/bundled/*.yaml) and the Documents cache filenames.
    // ------------------------------------------------------------------------

    private enum File {
        static let food        = "food.yaml"
        static let ingredients = "ingredients.yaml"
        static let meals       = "meals.yaml"
        static let supplements = "supplements.yaml"
        static let rda         = "rda.yaml"

        static let all = [food, ingredients, meals, supplements, rda]
    }

    private static let shasDefaultsKey = "ConfigStore.shas"

    // ------------------------------------------------------------------------
    // Loading
    // ------------------------------------------------------------------------

    /// Load + parse the config at launch. Prefers the Documents cache (the last
    /// successful refresh); falls back to the bundled YAML copies. Publishes the
    /// result on `data`. Never throws — on any failure `data` is left nil and the
    /// problem is logged, so the orchestrator can decide how to surface it.
    func loadInitial() {
        do {
            let texts = try loadSectionTexts()
            data = try parse(texts)
        } catch {
            // Leave `data` as-is (nil on first run). The app can prompt a manual
            // refresh; we don't crash the launch over a missing/corrupt cache.
            print("ConfigStore.loadInitial failed: \(error)")
        }
    }

    /// Read each section's YAML text, preferring the Documents cache and falling
    /// back per-file to the bundled copy. Throws if a section can't be found in
    /// either location.
    private func loadSectionTexts() throws -> [String: String] {
        var texts: [String: String] = [:]
        for name in File.all {
            if let cached = documentsURL(for: name),
               FileManager.default.fileExists(atPath: cached.path),
               let text = try? String(contentsOf: cached, encoding: .utf8) {
                texts[name] = text
                continue
            }
            guard let bundled = bundledURL(for: name) else {
                throw ConfigStoreError.missingResource(name)
            }
            texts[name] = try String(contentsOf: bundled, encoding: .utf8)
        }
        return texts
    }

    /// Parse the five raw YAML strings into a `ConfigData`. Decode failures name
    /// the offending file.
    private func parse(_ texts: [String: String]) throws -> ConfigData {
        let decoder = YAMLDecoder()

        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            guard let text = texts[name] else {
                throw ConfigStoreError.missingResource(name)
            }
            do {
                return try decoder.decode(T.self, from: text)
            } catch {
                throw ConfigStoreError.parse(file: name, underlying: error)
            }
        }

        // food.yaml / ingredients.yaml are top-level arrays.
        let foods       = try decode([ConfigFood].self, File.food)
        let ingredients = try decode([ConfigIngredient].self, File.ingredients)
        // meals.yaml / supplements.yaml are top-level maps (profile slug -> rows).
        let meals       = try decode([String: [ConfigMealRow]].self, File.meals)
        let supplements = try decode([String: [ConfigSupplement]].self, File.supplements)
        // rda.yaml is a top-level map (nutrient key -> thresholds).
        let rda         = try decode([String: ConfigRDA].self, File.rda)

        return ConfigData(foods: foods,
                          ingredients: ingredients,
                          meals: meals,
                          supplements: supplements,
                          rda: rda)
    }

    // ------------------------------------------------------------------------
    // Applying / persisting
    // ------------------------------------------------------------------------

    /// Atomically adopt `newData`: re-encode each section to YAML, write all five
    /// files into Documents, then publish the new value on `data`. If any encode
    /// or write fails, nothing is published and the previous state is untouched.
    func apply(_ newData: ConfigData) throws {
        let encoder = YAMLEncoder()

        // Encode every section up front so a failure aborts before we touch disk.
        let texts: [String: String] = [
            File.food:        try encoder.encode(newData.foods),
            File.ingredients: try encoder.encode(newData.ingredients),
            File.meals:       try encoder.encode(newData.meals),
            File.supplements: try encoder.encode(newData.supplements),
            File.rda:         try encoder.encode(newData.rda),
        ]

        // Persist (atomic per file). Throws on the first failure.
        for (name, text) in texts {
            guard let url = documentsURL(for: name) else {
                throw ConfigStoreError.documentsUnavailable
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        data = newData
    }

    // ------------------------------------------------------------------------
    // Change-detection shas (per filename), persisted in UserDefaults.
    // ------------------------------------------------------------------------

    /// The per-file blob shas from the last successful refresh (empty if none).
    func cachedShas() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: Self.shasDefaultsKey) as? [String: String] ?? [:]
    }

    /// Persist the per-file blob shas after a successful apply.
    func saveShas(_ shas: [String: String]) {
        UserDefaults.standard.set(shas, forKey: Self.shasDefaultsKey)
    }

    // ------------------------------------------------------------------------
    // Mapping helpers: ConfigData -> runtime model types
    // ------------------------------------------------------------------------

    /// Map every `ConfigFood` to a runtime `Food`. Unknown type / unit raw values
    /// fall back to `.produce` / `.gram` rather than dropping the row.
    func runtimeFoods() -> [Food] {
        guard let data else { return [] }
        return data.foods.map { f in
            Food(name: f.name,
                 type: IngredientType(rawValue: f.type) ?? .produce,
                 defaultAmount: f.defaultAmount,
                 stepAmount: f.stepAmount,
                 consumptionUnit: Self.unit(from: f.consumptionUnit),
                 consumptionGrams: f.consumptionGrams,
                 currentIngredientName: f.currentVariant ?? "")
        }
    }

    /// Map every `ConfigIngredient` to a runtime `Ingredient` via the JSON bridge.
    /// Each config row is expanded into the full flat key set the `Ingredient`
    /// `Codable` shape requires, serialized to JSON, and decoded. A decode failure
    /// throws an error naming the ingredient (rows are never silently skipped).
    func runtimeIngredients() throws -> [Ingredient] {
        guard let data else { return [] }
        let decoder = JSONDecoder()
        return try data.ingredients.map { ci in
            let dict = flatIngredientDict(from: ci)
            let json: Data
            do {
                json = try JSONSerialization.data(withJSONObject: dict, options: [])
            } catch {
                throw ConfigStoreError.ingredientEncode(name: ci.name, underlying: error)
            }
            do {
                return try decoder.decode(Ingredient.self, from: json)
            } catch {
                throw ConfigStoreError.ingredientDecode(name: ci.name, underlying: error)
            }
        }
    }

    /// Meal rows for a profile slug (empty if the profile isn't present).
    func mealRows(forSlug slug: String) -> [ConfigMealRow] {
        data?.meals[slug] ?? []
    }

    /// Supplement rows for a profile slug (empty if the profile isn't present).
    func supplements(forSlug slug: String) -> [ConfigSupplement] {
        data?.supplements[slug] ?? []
    }

    /// The RDA table (nutrient key -> thresholds).
    func rda() -> [String: ConfigRDA] {
        data?.rda ?? [:]
    }

    // ------------------------------------------------------------------------
    // Ingredient flat-dict construction
    // ------------------------------------------------------------------------
    //
    // The runtime `Ingredient` synthesizes its CodingKeys from its stored
    // property names, so the JSON keys are exactly the Swift property names
    // (camelCase) — NOT the kebab-case YAML keys. Its `init(from:)` calls plain
    // (non-optional) `decode(...)` for almost every key, so the dict must carry
    // EVERY key with a value of the right JSON type. Anything absent in the
    // config defaults to 0 / "" / [] / false here.
    //
    // `consumptionUnit` is a no-payload enum that Swift encodes as
    // `{"<caseName>": {}}` — we reproduce that exact shape.

    private func flatIngredientDict(from ci: ConfigIngredient) -> [String: Any] {
        // Per-nutrient lookup against the kebab-keyed `nutrients` map. Returns 0
        // when the nutrient is absent (only non-zero nutrients are listed).
        let nutrients = ci.nutrients ?? [:]
        func n(_ kebabKey: String) -> Double { nutrients[kebabKey] ?? 0 }

        // Consumption unit: validate against the Unit enum, defaulting to gram.
        let unitRaw = Self.unitName(ci.consumptionUnit)

        var dict: [String: Any] = [:]

        // --- identity / descriptive ---
        dict["id"]        = UUID().uuidString
        dict["name"]      = ci.name
        dict["brand"]     = ci.brand ?? ""
        dict["fullName"]  = ""
        dict["category"]  = ""
        dict["foodName"]  = ci.food
        dict["url"]       = ci.url ?? ""
        dict["verified"]  = ci.verified ?? ""

        // --- price ---
        dict["totalCost"]  = ci.price?.totalCost ?? 0
        dict["totalGrams"] = ci.price?.totalGrams ?? 0

        // --- collections ---
        dict["ingredients"]     = [String]()
        dict["allergens"]       = [String]()
        dict["mealAdjustments"] = [Any]()

        // --- core macros (top-level config fields) ---
        dict["servingSize"] = ci.servingSize ?? 0
        dict["calories"]    = ci.calories ?? 0
        dict["fat"]         = ci.fat ?? 0
        dict["fiber"]       = ci.fiber ?? 0
        dict["netCarbs"]    = ci.netCarbs ?? 0
        dict["protein"]     = ci.protein ?? 0

        // --- extended macros (may appear in the nutrients map) ---
        dict["carbohydrates"]      = n("carbohydrates")
        dict["sugar"]              = n("sugar")
        dict["addedSugar"]         = n("added-sugar")
        dict["sugarAlcohool"]      = n("sugar-alcohol")
        dict["saturatedFat"]       = n("saturated-fat")
        dict["transFat"]           = n("trans-fat")
        dict["monounsaturatedFat"] = n("monounsaturated-fat")
        dict["polyunsaturatedFat"] = n("polyunsaturated-fat")
        dict["cholesterol"]        = n("cholesterol")
        dict["sodium"]             = n("sodium")
        dict["omega3"]             = n("omega3")

        // --- micronutrients (kebab -> camel where they differ) ---
        dict["zinc"]            = n("zinc")
        dict["vitaminK"]        = n("vitamin-k")
        dict["vitaminE"]        = n("vitamin-e")
        dict["vitaminD"]        = n("vitamin-d")
        dict["vitaminC"]        = n("vitamin-c")
        dict["vitaminB6"]       = n("vitamin-b6")
        dict["vitaminB12"]      = n("vitamin-b12")
        dict["vitaminA"]        = n("vitamin-a")
        dict["thiamin"]         = n("thiamin")
        dict["selenium"]        = n("selenium")
        dict["riboflavin"]      = n("riboflavin")
        dict["potassium"]       = n("potassium")
        dict["phosphorus"]      = n("phosphorus")
        dict["pantothenicAcid"] = n("pantothenic-acid")
        dict["niacin"]          = n("niacin")
        dict["manganese"]       = n("manganese")
        dict["magnesium"]       = n("magnesium")
        dict["iron"]            = n("iron")
        dict["folicAcid"]       = n("folic-acid")
        dict["folate"]          = n("folate")
        dict["copper"]          = n("copper")
        dict["calcium"]         = n("calcium")

        // --- consumption / portioning ---
        // Unit's synthesized Codable shape: an empty object under the case name.
        dict["consumptionUnit"]  = [unitRaw: [String: Any]()]
        dict["consumptionGrams"] = ci.consumptionGrams ?? 1
        dict["meatAmount"]       = 0
        dict["stepAmount"]       = 0
        dict["defaultAmount"]    = 0

        // --- flags ---
        dict["microNutrients"] = false
        dict["foodActive"]     = true

        return dict
    }

    // ------------------------------------------------------------------------
    // File-location helpers
    // ------------------------------------------------------------------------

    /// The Documents-directory URL for a cached section file (nil if Documents
    /// is somehow unavailable).
    private func documentsURL(for filename: String) -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(filename)
    }

    /// The bundled-copy URL for a section file. Bundled copies ship as resources
    /// named e.g. "food.yaml"; `Bundle` indexes them by base name + extension.
    private func bundledURL(for filename: String) -> URL? {
        let base = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension
        return Bundle.main.url(forResource: base, withExtension: ext)
    }
}

// ----------------------------------------------------------------------------
// Errors
// ----------------------------------------------------------------------------

enum ConfigStoreError: LocalizedError {
    /// A section file was found in neither Documents nor the app bundle.
    case missingResource(String)
    /// A YAML section failed to decode into its wire type.
    case parse(file: String, underlying: Error)
    /// Documents directory was unavailable while persisting.
    case documentsUnavailable
    /// A config ingredient couldn't be serialized to JSON.
    case ingredientEncode(name: String, underlying: Error)
    /// A config ingredient's JSON failed to decode into a runtime Ingredient.
    case ingredientDecode(name: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Config resource '\(name)' is missing from both Documents and the app bundle."
        case .parse(let file, let underlying):
            return "Failed to parse config file '\(file)': \(underlying.localizedDescription)"
        case .documentsUnavailable:
            return "The Documents directory is unavailable; cannot persist config."
        case .ingredientEncode(let name, let underlying):
            return "Failed to encode ingredient '\(name)': \(underlying.localizedDescription)"
        case .ingredientDecode(let name, let underlying):
            return "Failed to build runtime ingredient '\(name)': \(underlying.localizedDescription)"
        }
    }
}


// String -> Unit helpers. `Unit` is a custom ValueType enum (not RawRepresentable);
// its case names match the config `consumption-unit` strings.
fileprivate extension ConfigStore {
    static func unitName(_ s: String?) -> String {
        let known: Set<String> = ["bar", "can", "cup", "egg", "gram", "piece", "pill", "slice", "tablespoon", "teaspoon", "whole"]
        let v = s ?? "gram"
        return known.contains(v) ? v : "gram"
    }
    static func unit(from s: String?) -> Unit {
        switch unitName(s) {
        case "bar": return .bar
        case "can": return .can
        case "cup": return .cup
        case "egg": return .egg
        case "piece": return .piece
        case "pill": return .pill
        case "slice": return .slice
        case "tablespoon": return .tablespoon
        case "teaspoon": return .teaspoon
        case "whole": return .whole
        default: return .gram
        }
    }
}
