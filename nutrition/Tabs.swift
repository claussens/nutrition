import SwiftUI

struct Tabs: View {
    @State var tab: String = "Meal"

    init() {
        // UITabBar.appearance().backgroundColor = UIColor(Color("Tab"))
        // UITabBar.appearance().barTintColor = UIColor(Color.green.opacity(0.5))
    }

    var body: some View {

        TabView(selection: $tab) {


            NavigationView {
                MealList()
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "fork.knife.circle")
                Text("Meal")
            }.tag("Meal")
              .navigationViewStyle(StackNavigationViewStyle())


            NavigationView {
                IngredientList()
                  .hiddenNavigationBarStyle()
                  // .navigationTitle("Ingredients")
            }.tabItem {
                Image(systemName: "cart.fill")
                Text("Prep")
            }.tag("Ingredients")
              .navigationViewStyle(StackNavigationViewStyle())


            NavigationView {
                HistoryView()
                  .hiddenNavigationBarStyle()
            }.tabItem {
                Image(systemName: "chart.xyaxis.line")
                Text("History")
            }.tag("History")
              .navigationViewStyle(StackNavigationViewStyle())


            NavigationView {
                ProfileEdit(tab: $tab)
                  .hiddenNavigationBarStyle()
                  // .navigationTitle("Profile")
            }.tabItem {
                Image(systemName: "person")
                Text("Profile")
            }.tag("Profile")
              .navigationViewStyle(StackNavigationViewStyle())
        }
          .accentColor(Color.theme.blueYellow)
    }
}
