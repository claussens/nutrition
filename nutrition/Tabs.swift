import SwiftUI

struct Tabs: View {
    @State var tab: String = "Meal"

    var body: some View {

        TabView(selection: $tab) {


            NavigationStack {
                MealList()
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "fork.knife.circle")
                Text("Meal")
            }.tag("Meal")


            NavigationStack {
                IngredientList()
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "cart.fill")
                Text("Prep")
            }.tag("Ingredients")


            NavigationStack {
                HistoryView()
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "chart.xyaxis.line")
                Text("History")
            }.tag("History")


            NavigationStack {
                ProfileEdit(tab: $tab)
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "person")
                Text("Profile")
            }.tag("Profile")
        }
          .accentColor(Color.theme.blueYellow)
    }
}
