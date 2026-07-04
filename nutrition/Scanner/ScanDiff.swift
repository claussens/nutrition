import Foundation

// ============================================================
// ScanDiff — what changes if we apply a `ParsedIngredient` to an
// existing `Ingredient`. Pure data; no UI, no I/O.
//
// We only diff fields the LLM actually filled in (non-nil on the
// parsed side). A nil parsed value means "not visible on the
// label", not "set to zero" — so we skip it.
// ============================================================
struct ScanDiff: Equatable {

    struct Change: Equatable, Identifiable {
        let id: String           // field name, used as Identifiable id
        let field: String        // human-readable label
        let oldValue: String
        let newValue: String
    }


    let changes: [Change]


    var isEmpty: Bool { changes.isEmpty }


    // ============================================================
    // Compute the diff between an existing ingredient and a parsed
    // result. Returns one Change per field that would actually
    // change value.
    //
    // Number comparisons use a small epsilon — the LLM round-trips
    // through JSON Doubles, so 0 vs 0.0000001 is noise.
    // ============================================================
    static func compute(existing: Ingredient, parsed: ParsedIngredient) -> ScanDiff {
        var out: [Change] = []

        // Identity / product details (strings)
        addStringChange(&out, field: "Name", id: "name",
                        old: existing.name, new: parsed.name)
        addOptStringChange(&out, field: "Brand", id: "brand",
                           old: existing.brand, new: parsed.brand)
        addOptStringChange(&out, field: "Full name", id: "fullName",
                           old: existing.fullName, new: parsed.fullName)
        addOptStringChange(&out, field: "URL", id: "url",
                           old: existing.url, new: parsed.url)
        addOptListChange(&out, field: "Ingredients", id: "ingredientsList",
                         old: existing.ingredients, new: parsed.ingredientsList)
        addOptListChange(&out, field: "Allergens", id: "allergens",
                         old: existing.allergens, new: parsed.allergens)

        // Serving / consumption
        addNumberChange(&out, field: "Serving size (g)", id: "servingSize",
                        old: existing.servingSize, new: parsed.servingSize)
        addNumberChange(&out, field: "Grams / unit", id: "consumptionGrams",
                        old: existing.consumptionGrams, new: parsed.consumptionGrams)
        if let unitString = parsed.consumptionUnit {
            let parsedUnit = parsed.consumptionUnitEnum
            if existing.consumptionUnit != parsedUnit {
                out.append(Change(
                    id: "consumptionUnit",
                    field: "Consumption unit",
                    oldValue: existing.consumptionUnit.singularForm,
                    newValue: parsedUnit.singularForm.isEmpty ? unitString : parsedUnit.singularForm
                ))
            }
        }

        // Pricing (verify-by-name flow). price → totalCost,
        // packageGrams → totalGrams.
        addNumberChange(&out, field: "Price ($)", id: "price",
                        old: existing.totalCost, new: parsed.price)
        addNumberChange(&out, field: "Package grams", id: "packageGrams",
                        old: existing.totalGrams, new: parsed.packageGrams)

        // Macros + V&M — one comparison per scannable nutrient in the
        // catalog (label, id, and both keypaths all come from the
        // descriptor, so compute() can't drift from apply()).
        for d in NutrientCatalog.scannable {
            addNumberChange(&out, field: d.label, id: d.id,
                            old: existing[keyPath: d.ingredient],
                            new: parsed[keyPath: d.parsed!])
        }

        return ScanDiff(changes: out)
    }


    // ============================================================
    // Helpers — each appends 0 or 1 Change. nil parsed = skip.
    // ============================================================

    private static func addNumberChange(_ out: inout [Change],
                                        field: String, id: String,
                                        old: Double, new: Double?) {
        guard let newVal = new else { return }
        if abs(old - newVal) < 0.0001 { return }
        out.append(Change(
            id: id, field: field,
            oldValue: formatNumber(old),
            newValue: formatNumber(newVal)
        ))
    }


    private static func addStringChange(_ out: inout [Change],
                                        field: String, id: String,
                                        old: String, new: String) {
        if old == new { return }
        out.append(Change(id: id, field: field, oldValue: old, newValue: new))
    }


    private static func addOptStringChange(_ out: inout [Change],
                                           field: String, id: String,
                                           old: String, new: String?) {
        guard let newVal = new, !newVal.isEmpty else { return }
        if old == newVal { return }
        out.append(Change(id: id, field: field,
                          oldValue: old.isEmpty ? "—" : old,
                          newValue: newVal))
    }


    private static func addOptListChange(_ out: inout [Change],
                                         field: String, id: String,
                                         old: [String], new: [String]?) {
        guard let newVal = new, !newVal.isEmpty else { return }
        if old == newVal { return }
        out.append(Change(id: id, field: field,
                          oldValue: old.isEmpty ? "—" : old.joined(separator: ", "),
                          newValue: newVal.joined(separator: ", ")))
    }


    // ============================================================
    // Apply selected parsed fields back onto an Ingredient. `ids`
    // are Change.id values (e.g. "fat", "price", "brand"); only
    // those whose parsed value is non-nil are written. Centralizes
    // the id→field mapping so compute() and apply() stay in sync.
    // ============================================================
    static func apply(parsed p: ParsedIngredient,
                      ids: Set<String>,
                      to ing: inout Ingredient) {
        func num(_ id: String, _ v: Double?, _ set: (Double) -> Void) {
            guard ids.contains(id), let v = v else { return }
            set(v)
        }
        func str(_ id: String, _ v: String?, _ set: (String) -> Void) {
            guard ids.contains(id), let v = v, !v.isEmpty else { return }
            set(v)
        }
        func list(_ id: String, _ v: [String]?, _ set: ([String]) -> Void) {
            guard ids.contains(id), let v = v, !v.isEmpty else { return }
            set(v)
        }

        str("name", p.name)             { ing.name = $0 }
        str("brand", p.brand)           { ing.brand = $0 }
        str("fullName", p.fullName)     { ing.fullName = $0 }
        str("url", p.url)               { ing.url = $0 }
        list("ingredientsList", p.ingredientsList) { ing.ingredients = $0 }
        list("allergens", p.allergens)  { ing.allergens = $0 }

        num("price", p.price)                     { ing.totalCost = $0 }
        num("packageGrams", p.packageGrams)       { ing.totalGrams = $0 }
        num("servingSize", p.servingSize)         { ing.servingSize = $0 }
        num("consumptionGrams", p.consumptionGrams) { ing.consumptionGrams = $0 }
        if ids.contains("consumptionUnit"), p.consumptionUnit != nil {
            ing.consumptionUnit = p.consumptionUnitEnum
        }

        // Macros + V&M — same catalog rows compute() diffed.
        for d in NutrientCatalog.scannable {
            num(d.id, p[keyPath: d.parsed!]) { ing[keyPath: d.ingredient] = $0 }
        }
    }


    // ============================================================
    // Today's date as a `verified` stamp. Matches the seed format
    // (e.g. "5/16/2026"): no leading zeros, en_US_POSIX so it's
    // locale-stable. One source of truth for the web-refresh flows.
    // ============================================================
    static func todayStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d/yyyy"
        return f.string(from: Date())
    }


    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        // Trim trailing zeros for readability ("1.5" not "1.50000")
        let s = String(format: "%.4f", value)
        var trimmed = s
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }
}
