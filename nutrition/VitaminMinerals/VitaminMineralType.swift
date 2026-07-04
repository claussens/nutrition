import Foundation


enum VitaminMineralType: ValueType, CaseIterable {
    case calcium
    case copper
    case folate
    case folicAcid
    case iron
    case magnesium
    case manganese
    case niacin
    case pantothenicAcid
    case phosphorus
    case potassium
    case riboflavin
    case selenium
    case thiamin
    case vitaminA
    case vitaminB12
    case vitaminB6
    case vitaminC
    case vitaminD
    case vitaminE
    case vitaminK
    case zinc


    func formattedString(_ precision: Int = 0) -> String {
        switch self {
        case .calcium:         return "Calcium"
        case .copper:          return "Copper"
        case .folate:          return "Folate"
        case .folicAcid:       return "Folic Acid"
        case .iron:            return "Iron"
        case .magnesium:       return "Magnesium"
        case .manganese:       return "Manganese"
        case .niacin:          return "Niacin"
        case .pantothenicAcid: return "Pantothenic Acid"
        case .phosphorus:      return "Phosphorus"
        case .potassium:       return "Potassium"
        case .riboflavin:      return "Riboflavin"
        case .selenium:        return "Selenium"
        case .thiamin:         return "Thiamin"
        case .vitaminA:        return "Vitamin A"
        case .vitaminB12:      return "Vitamin B12"
        case .vitaminB6:       return "Vitamin B6"
        case .vitaminC:        return "Vitamin C"
        case .vitaminD:        return "Vitamin D"
        case .vitaminE:        return "Vitamin E"
        case .vitaminK:        return "Vitamin K"
        case .zinc:            return "Zinc"
        }
    }


    func singular() -> Bool {
        return true
    }
}
