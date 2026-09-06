import SwiftUI


struct AdjustmentList: View {

    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var foodMgr: FoodMgr

    @State var showInactive: Bool = false


    var body: some View {
        List {
            IngredientRowHeader(showGroup: true)
              .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))

            ForEach(adjustmentMgr.getAll(includeInactive: showInactive)) { adjustment in
                NavigationLink(destination: AdjustmentEdit(adjustment: adjustment),
                               label: {
                                   IngredientRow(showGroup: true,
                                                 name: adjustment.name,
                                                 group: adjustment.group,
                                                 amount: adjustment.amount,
                                                 consumptionUnit: foodMgr.consumptionUnit(for: adjustment.name, ingredientMgr: ingredientMgr))
                               })
                  .foregroundColor(adjustment.active ? Color.theme.blackWhite : Color.theme.red)
                  .swipeActions(edge: .leading) {
                      Button {
                          adjustmentMgr.toggleActive(adjustment)
                      } label: {
                          Label("", systemImage: adjustment.active ? "pause.circle" : "play.circle")
                      }
                        .tint(adjustment.active ? Color.theme.red : Color.theme.green)
                  }
                  .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                          adjustmentMgr.delete(adjustment)
                      } label: {
                          Label("Delete", systemImage: "trash.fill")
                      }
                  }
            }
              .onMove(perform: moveAction)
              .onDelete(perform: deleteAction)
              .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        }
          .environment(\.defaultMinListRowHeight, 5)
          .padding([.leading, .trailing], -20)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  EditButton()
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItem(placement: .principal) {
                  Button {
                      showInactive.toggle()
                  } label: {
                      Image(systemName: showInactive ? "eye" : "eye.slash")
                  }
                    .foregroundColor(Color.theme.blueYellow)
                    .opacity(adjustmentMgr.inactiveIngredientsExist() ? 1 : 0)
              }
              ToolbarItem(placement: .primaryAction) {
                  NavigationLink("Add", destination: AdjustmentAdd())
                    .foregroundColor(Color.theme.blueYellow)
              }
          }
    }


    func moveAction(from source: IndexSet, to destination: Int) {
        adjustmentMgr.move(from: source, to: destination)
    }


    func deleteAction(indexSet: IndexSet) {
        adjustmentMgr.deleteSet(indexSet: indexSet)
    }
}


struct AdjustmentList_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdjustmentList()
              .environmentObject(AdjustmentMgr(profileId: "preview"))
        }
    }
}
