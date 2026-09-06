import SwiftUI

// The adjustment-list row (name | group | amount unit). The only
// caller is AdjustmentList; the meal page has its own MealRowView.
struct IngredientRowHeader: View {
    var showGroup: Bool = false
    var showAmount: Bool = true

    // TODO: Figure out why these percentages vary from the data rows
    var nameWidthPercentage: Double = 0.38
    var choiceGroupWidthPercentage: Double = 0.34
    var amountWidthPercentage: Double = 0.1
    var unitWidthPercentage: Double = 0.15

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 5) {
                Text("Food").font(.caption).foregroundColor(Color.theme.blueYellow).frame(width: nameWidthPercentage * geo.size.width, alignment: .leading)

                if showGroup {
                    Text("Group").font(.caption).foregroundColor(Color.theme.blueYellow).frame(width: choiceGroupWidthPercentage * geo.size.width, alignment: .center)
                }

                if showAmount {
                    Text("Amount").font(.caption).foregroundColor(Color.theme.blueYellow).frame(width: (amountWidthPercentage + unitWidthPercentage) * geo.size.width, alignment: .center)
                }
            }
        }
    }
}

struct IngredientRow: View {
    var showGroup: Bool = false
    var showAmount: Bool = true

    var nameWidthPercentage: Double = 0.395
    var choiceGroupWidthPercentage: Double = 0.36
    var amountWidthPercentage: Double = 0.1
    var unitWidthPercentage: Double = 0.15

    var name: String
    var group: String = ""
    var amount: Double = 0
    var consumptionUnit: Unit = Unit.gram

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 5) {
                Text(name).font(.callout).frame(width: nameWidthPercentage * geo.size.width, alignment: .leading)

                if showGroup {
                    Text("\(group)").font(.caption).frame(width: choiceGroupWidthPercentage * geo.size.width, alignment: .center)
                }

                if showAmount {
                    Text("\(amount.formattedString(1))").font(.callout).frame(width: amountWidthPercentage * geo.size.width, alignment: .trailing)
                    Text(amount == 1 ? consumptionUnit.singularForm : consumptionUnit.pluralForm).font(.caption).frame(width: unitWidthPercentage * geo.size.width, alignment: .leading)
                }
            }.frame(height: 9)
        }
    }
}
