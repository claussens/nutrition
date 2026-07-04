import SwiftUI


// Per-nutrient deficiency / excess summaries shown when the user's
// daily total is outside the NIH RDA / UL band.  Text is intentionally
// short — one sentence each — and the NIH fact-sheet URL (already
// referenced in source comments next to each min/max accessor in
// VitaminMineral.swift) is surfaced as a tappable Link below the note.
//
// excessRisks is empty for nutrients without an established UL or
// where the UL applies only to supplemental intake; in those cases
// the over-max banner is suppressed (the V&M list also hides Max for
// those nutrients).
struct NutrientImplication {
    let nihURL: String
    let deficiencyRisks: String
    let excessRisks: String
}


private func implication(for type: VitaminMineralType) -> NutrientImplication {
    switch type {
    case .calcium: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Calcium-HealthProfessional",
        deficiencyRisks: "Bone loss, osteoporosis, muscle cramps, increased fracture risk over time.",
        excessRisks: "Kidney stones, impaired iron and zinc absorption, possible cardiovascular risk.")
    case .copper: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Copper-HealthProfessional",
        deficiencyRisks: "Anemia, neutropenia, neurological symptoms (numbness, weakness).",
        excessRisks: "Liver damage, GI distress, possible neurological effects.")
    case .folate: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Folate-HealthProfessional",
        deficiencyRisks: "Megaloblastic anemia, fatigue; in pregnancy, neural tube defects.",
        excessRisks: "")  // UL applies to synthetic folic acid only, not food folate
    case .folicAcid: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Folate-HealthProfessional",
        deficiencyRisks: "Megaloblastic anemia; neural tube defects in pregnancy.",
        excessRisks: "May mask vitamin B12 deficiency; possible cancer-progression concerns at high doses.")
    case .iron: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Iron-HealthProfessional",
        deficiencyRisks: "Iron-deficiency anemia: fatigue, pallor, reduced exercise capacity, impaired immunity.",
        excessRisks: "GI distress, oxidative stress; in chronic excess, liver and cardiac damage.")
    case .magnesium: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Magnesium-HealthProfessional",
        deficiencyRisks: "Muscle cramps, fatigue, arrhythmia, insulin resistance, low bone density.",
        excessRisks: "")  // UL is for supplemental Mg only
    case .manganese: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Manganese-HealthProfessional",
        deficiencyRisks: "Rare; possible bone demineralization and impaired growth.",
        excessRisks: "Neurotoxicity (Parkinsonian symptoms) at very high chronic intakes.")
    case .niacin: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Niacin-HealthProfessional",
        deficiencyRisks: "Pellagra: dermatitis, diarrhea, dementia.",
        excessRisks: "")  // UL applies to supplemental / fortified niacin only
    case .pantothenicAcid: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/PantothenicAcid-HealthProfessional",
        deficiencyRisks: "Very rare; fatigue, irritability, paresthesias.",
        excessRisks: "")  // No established UL
    case .phosphorus: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Phosphorus-HealthProfessional",
        deficiencyRisks: "Bone loss, weakness, anorexia; rare in normal diets.",
        excessRisks: "Vascular and renal calcification, especially with kidney impairment.")
    case .potassium: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Potassium-HealthProfessional",
        deficiencyRisks: "Elevated blood pressure, kidney stones, glucose intolerance, arrhythmia.",
        excessRisks: "")  // No UL set for healthy adults
    case .riboflavin: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Riboflavin-HealthProfessional",
        deficiencyRisks: "Sore throat, cracked lips, anemia, skin disorders.",
        excessRisks: "")  // No established UL
    case .selenium: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Selenium-HealthProfessional",
        deficiencyRisks: "Cardiomyopathy (Keshan disease), thyroid dysfunction, weakened immunity.",
        excessRisks: "Selenosis: hair and nail brittleness, GI distress, neurological symptoms.")
    case .thiamin: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Thiamin-HealthProfessional",
        deficiencyRisks: "Beriberi, Wernicke-Korsakoff syndrome, nerve damage.",
        excessRisks: "")  // No established UL
    case .vitaminA: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminA-HealthProfessional",
        deficiencyRisks: "Night blindness, immune dysfunction; severe cases cause xerophthalmia.",
        excessRisks: "Liver toxicity, bone fragility, birth defects (preformed retinol only).")
    case .vitaminB12: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminB12-HealthProfessional",
        deficiencyRisks: "Megaloblastic anemia, neuropathy, fatigue, cognitive decline.",
        excessRisks: "")  // No established UL
    case .vitaminB6: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminB6-HealthProfessional",
        deficiencyRisks: "Anemia, dermatitis, depression, confusion, weakened immunity.",
        excessRisks: "Sensory neuropathy at high chronic supplemental doses.")
    case .vitaminC: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminC-HealthProfessional",
        deficiencyRisks: "Scurvy: bleeding gums, poor wound healing, fatigue, joint pain.",
        excessRisks: "GI distress (diarrhea, cramps); possible kidney stones at very high doses.")
    case .vitaminD: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional",
        deficiencyRisks: "Bone loss, rickets/osteomalacia, muscle weakness, weakened immunity.",
        excessRisks: "Hypercalcemia: nausea, kidney stones, vascular calcification.")
    case .vitaminE: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminE-HealthProfessional",
        deficiencyRisks: "Rare; nerve and muscle damage, hemolytic anemia, immune dysfunction.",
        excessRisks: "")  // UL applies to supplemental α-tocopherol only
    case .vitaminK: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/VitaminK-HealthProfessional",
        deficiencyRisks: "Impaired clotting, easy bruising; reduced bone mineral density over time.",
        excessRisks: "")  // No established UL
    case .zinc: return .init(
        nihURL: "https://ods.od.nih.gov/factsheets/Zinc-HealthProfessional",
        deficiencyRisks: "Slow growth, hair loss, impaired immunity, taste disturbance, poor wound healing.",
        excessRisks: "Copper deficiency, GI distress, weakened immunity at chronic high intakes.")
    }
}


struct VitaminMineralContributors: View {

    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var profileMgr: ProfileMgr

    let nutrient: VitaminMineralType


    var body: some View {
        let contributions = contributorsTo(
            nutrient: nutrient,
            mealIngredients: mealIngredientMgr.mealIngredients,
            resolver: MealResolver(ingredientMgr: ingredientMgr,
                                   foodMgr: foodMgr,
                                   profile: profileMgr.profile)
        )
        let total = contributions.reduce(0) { $0 + $1.contribution }
        let vm = VitaminMineral(name: nutrient,
                                age: profileMgr.profile.age,
                                gender: profileMgr.profile.gender)
        let unitLabel = vm.unit().pluralForm
        let unitSingular = vm.unit().singularForm
        let info = implication(for: nutrient)
        let rdaMin = vm.min()
        // Every ingredient in the database that contains this nutrient,
        // ranked by per-gram density. Tells the user *what to eat* to
        // close a gap, independent of what's currently on today's plate.
        let allSources = allContributorsFor(
            nutrient: nutrient,
            rdaMin: rdaMin,
            ingredientMgr: ingredientMgr
        )

        return List {
            implicationSection(total: total, vm: vm, unitLabel: unitLabel, info: info)

            Section {
                if contributions.isEmpty {
                    Text("No active meal ingredient contributes to \(nutrient.formattedString()).")
                      .font(.callout)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                } else {
                    ForEach(contributions) { c in
                        HStack(spacing: 8) {
                            Text(c.ingredientName)
                              .font(.callout)
                              .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(c.amount.formattedString(0)) \(c.consumptionUnit.pluralForm)")
                              .font(.caption2)
                              .foregroundColor(Color.theme.blackWhiteSecondary)
                              .frame(width: 90, alignment: .trailing)
                            Text("\(c.contribution.formattedString(1))")
                              .font(.caption)
                              .frame(width: 60, alignment: .trailing)
                            Text(total > 0 ? "(\(Int((c.contribution / total) * 100))%)" : "")
                              .font(.caption2)
                              .foregroundColor(Color.theme.blackWhiteSecondary)
                              .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("Contributors (today's meal)")
            } footer: {
                let minStr = vm.min().formattedString(0)
                // Suppress Max when no UL applies to total intake (no UL set,
                // or UL applies to supplements only — same rule as the V&M list).
                let maxApplies = vm.max() > 0 && !info.excessRisks.isEmpty
                let maxStr = maxApplies ? vm.max().formattedString(0) : "—"
                Text("Total \(total.formattedString(1)) \(unitLabel)   |   Min \(minStr)   |   Max \(maxStr)")
                  .font(.caption2)
            }

            Section {
                if allSources.isEmpty {
                    Text("No ingredient in the database lists \(nutrient.formattedString()).")
                      .font(.callout)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                } else {
                    ForEach(allSources) { row in
                        HStack(spacing: 8) {
                            Text(row.name)
                              .font(.callout)
                              .frame(maxWidth: .infinity, alignment: .leading)
                            // Grams of this ingredient needed to reach the
                            // RDA min. "—" when there's no min defined
                            // (e.g., folic acid in some age bands).
                            Text(rdaMin > 0
                                 ? "\(row.gramsForMin.formattedString(0))g"
                                 : "—")
                              .font(.callout)
                              .frame(width: 80, alignment: .trailing)
                            // Per-100g density for context.
                            Text("(\(row.perHundredGrams.formattedString(0)) \(unitSingular)/100g)")
                              .font(.caption2)
                              .foregroundColor(Color.theme.blackWhiteSecondary)
                              .frame(width: 130, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("All Sources (best per-gram first)")
            } footer: {
                if rdaMin > 0 {
                    Text("Grams of each ingredient to reach the RDA min of \(rdaMin.formattedString(0)) \(unitLabel) on its own.")
                      .font(.caption2)
                }
            }
        }
          .navigationTitle("\(nutrient.formattedString()) Contributors")
    }


    // Banner shown above Contributors when the day's total is outside
    // the RDA/UL band.  Hidden entirely when intake is in range so
    // the page stays clean.  Returns AnyView for compile-time uniformity
    // since the section may be empty.
    @ViewBuilder
    private func implicationSection(total: Double, vm: VitaminMineral, unitLabel: String, info: NutrientImplication) -> some View {
        let minVal = vm.min()
        let maxVal = vm.max()
        let belowMin = total < minVal
        // Only flag over-max when the nutrient has a meaningful UL
        // *and* that UL applies to total (food-inclusive) intake — both
        // conditions are encoded by excessRisks being non-empty.
        let aboveMax = maxVal > 0 && total > maxVal && !info.excessRisks.isEmpty

        if belowMin || aboveMax {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if belowMin {
                        Text("⚠️ Below RDA (\(minVal.formattedString(0)) \(unitLabel))")
                          .font(.callout)
                          .foregroundColor(Color.theme.red)
                        Text("Deficiency risks: \(info.deficiencyRisks)")
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    } else {
                        Text("⚠️ Above UL (\(maxVal.formattedString(0)) \(unitLabel))")
                          .font(.callout)
                          .foregroundColor(Color.theme.red)
                        Text("Excess risks: \(info.excessRisks)")
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    }
                    if let url = URL(string: info.nihURL) {
                        Link("→ Learn more (ods.od.nih.gov)", destination: url)
                          .font(.caption)
                    }
                }
                  .padding(.vertical, 4)
            }
        }
    }
}
