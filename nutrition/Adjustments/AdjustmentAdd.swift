import SwiftUI


struct AdjustmentAdd: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr

    @State var name: String = ""
    @State var amount: Double = 0
    @State var constraints: Bool = false
    @State var maximum: Double = 0
    @State var group: String = ""


    var body: some View {
        Form {
            Section {
                // A rule targets a FOOD (meal rows are keyed by Food
                // name); one rule per Food, so Foods that already have
                // one are left out.
                NameValue("Food", $name, options: addableFoodNames(), control: .picker)
                if name.count > 0 {
                    NameValue("Amount", $amount, foodMgr.consumptionUnit(for: name, ingredientMgr: ingredientMgr), edit: true)
                }
            }
            //            if name.count > 0 {
            //                Section {
            //                    NameValue("Constraints", $constraints, control: .toggle)
            //                    if constraints {
            //                        NameValue("Maximum", $maximum, edit: true)
            //                    }
            //                }
            //                Section {
            //                    NameValue("Choice Group", $group, edit: true)
            //                }
            //            }
        }
          .padding([.leading, .trailing], -20)
          .cancelSaveToolbar(saveDisabled: name.isEmpty, onCancel: cancel, onSave: save)
    }


    private func addableFoodNames() -> [String] {
        let taken = Set(adjustmentMgr.getNames())
        return foodMgr.namesSorted.filter { !taken.contains($0) }
    }


    func cancel() {
        withAnimation {
            self.presentationMode.wrappedValue.dismiss()
        }
    }


    func save() {
        withAnimation {
            adjustmentMgr.create(name: name, amount: amount, group: group, active: true)
            presentationMode.wrappedValue.dismiss()
        }
    }
}


struct AdjustmentCreate_Previews: PreviewProvider {

    static var previews: some View {
        NavigationView {
            AdjustmentAdd()
              .environmentObject(AdjustmentMgr(profileId: "preview"))
        }
    }
}
