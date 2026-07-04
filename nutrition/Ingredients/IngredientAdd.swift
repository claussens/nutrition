import SwiftUI

struct IngredientAdd: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr

    // Optional scan result. When non-nil, fields are populated
    // from it on appear, and the names listed in
    // `lowConfidenceFields` get a yellow tint in the form.
    let prefill: ParsedIngredient?

    init(prefill: ParsedIngredient? = nil) {
        self.prefill = prefill
    }

    // The whole form edits this blank draft in place — one binding
    // per field instead of the old pile of scalar @States plus a
    // nutrient dict copied over at save. Nothing touches
    // IngredientMgr until Save.
    @State private var draft = Ingredient(name: "",
                                          servingSize: 0,
                                          calories: 0,
                                          fat: 0,
                                          fiber: 0,
                                          netCarbs: 0,
                                          protein: 0,
                                          consumptionUnit: .gram,
                                          consumptionGrams: 1.0,
                                          meatAmount: 0)

    // Category for a brand-new Food created from this screen. An
    // existing Food's type is inherited and never edited here.
    @State private var newFoodType: IngredientType = .produce

    @State var ingredientAdd: Bool = false
    @State var ingredientAmount: Double = 0

    @State var adjustmentAdd: Bool = false
    @State var adjustmentAmount: Double = 0

    var body: some View {
        Form {
            if let prefill = prefill, !prefill.lowConfidenceFields.isEmpty {
                LowConfidenceBanner(fields: prefill.lowConfidenceFields)
            }
            Section {
                NameValue("Name", $draft.name, edit: true)
            }
            IngredientFormSections(ingredient: $draft,
                                   mode: .add,
                                   newFoodType: $newFoodType)
            quickAddSection
        }
          .padding([.leading, .trailing], -20)
          .onAppear { applyPrefill() }
          .cancelSaveToolbar(onCancel: cancel, onSave: save)
    }

    func cancel() {
        withAnimation {
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    func save() {
        withAnimation {
            // The draft already carries every field (core macros,
            // extended macros, V&M) through its form bindings, so
            // there's no per-catalog copy step here.
            ingredientMgr.add(draft)
            if !draft.foodName.isEmpty {
                foodMgr.ensure(name: draft.foodName,
                               defaultMember: draft.name,
                               type: foodMgr.getByName(name: draft.foodName)?.type ?? newFoodType)
            }
            if ingredientAdd {
                mealIngredientMgr.create(name: draft.name,
                                         amount: ingredientAmount)
            }
            if adjustmentAdd {
                adjustmentMgr.create(name: draft.name,
                                     amount: adjustmentAmount,
                                     active: false)
            }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct IngredientAdd2_Previews: PreviewProvider {

    static var previews: some View {
        IngredientAdd()
    }
}

extension IngredientAdd {

    // Apply LLM-parsed values to the blank draft via the shared
    // Ingredient.applyParsed (IngredientFormSections.swift) — only
    // fields the LLM actually filled in (non-nil) are touched.
    fileprivate func applyPrefill() {
        guard let p = prefill else { return }
        draft.applyParsed(p)
    }


    private var quickAddSection: some View {
        Group {
            Section(header: Text("Meal Ingredients Quick Add")) {
                NameValue("Add to Meal Ingredients", $ingredientAdd, control: .toggle)
                if ingredientAdd {
                    NameValue("Ingredient Amount", $ingredientAmount, edit: true)
                }
            }

            Section(header: Text("Meal Adjustments Quick Add")) {
                NameValue("Add to Adjustments", $adjustmentAdd, control: .toggle)
                if adjustmentAdd {
                    NameValue("Adjustment Amount", $adjustmentAmount, edit: true)
                }
            }
        }
    }
}
