import SwiftUI

struct MealConfigure: View {

    enum Field: Hashable {
        case activeCaloriesBurned
    }

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var profileMgr: ProfileMgr

    @FocusState var focusedField: Field?

    // Local editing draft (same pattern as ProfileEdit): rows bind to
    // this copy so keystrokes never touch the manager; Save is the
    // single commit point and Cancel just discards the draft. The
    // placeholder is replaced by the real active profile in onAppear.
    @State private var draft = Profile(
        dateOfBirth: Date(), gender: .male, height: 0,
        bodyMassFromHealthKit: false, bodyMass: 0,
        bodyFatPercentageFromHealthKit: false, bodyFatPercentage: 0,
        activeCaloriesBurned: 0, proteinRatio: 0,
        calorieDeficit: 0, netCarbsMaximum: 0)


    var body: some View {
        Form {
            Section {
                NameValue("Active Calories Burned", description: "daily calories burned due to exercise/movement", $draft.activeCaloriesBurned, .calorie, edit: true)
                  .focused($focusedField, equals: .activeCaloriesBurned)
                if !draft.bodyMassFromHealthKit {
                    NameValue("Weight", $draft.bodyMass, .pound, precision: 1, edit: true)
                }
                if !draft.bodyFatPercentageFromHealthKit {
                    NameValue("Body Fat %", $draft.bodyFatPercentage, .percentage, precision: 1, edit: true)
                }
                NameValue("Protein Ratio", description: "daily protein grams required / lb of lean body mass", $draft.proteinRatio, precision: 2, edit: true)
                NameValue("Caloric Deficit", description: "percentage to adjust daily caloric and macro goals", $draft.calorieDeficit, .percentage, edit: true)
                NameValue("Water Minimum", description: "daily consumption mininimum, weight/2 * ~.03", $draft.waterLiters, .liter, precision: 1)
            }
            // Meat picker / weight removed — meat is now an ordinary
            // grouped Food. Add it to the meal from the Prep page or
            // the Meal Add dialog; duplicate any row by double-tapping
            // it; switch a row's member via long-press.
        }
          .padding([.leading, .trailing], -20)
          .onAppear {
              draft = profileMgr.profile
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                  self.focusedField = .activeCaloriesBurned
              }
          }
          .cancelSaveToolbar(onCancel: cancel, onSave: save)
    }

    // Cancel = discard the draft; nothing was written while editing.
    func cancel() {
        withAnimation {
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    // Save = commit the draft to the manager (persists via didSet).
    func save() {
        withAnimation {
            profileMgr.profile = draft
            profileMgr.serialize()
            presentationMode.wrappedValue.dismiss()
        }
    }
}
