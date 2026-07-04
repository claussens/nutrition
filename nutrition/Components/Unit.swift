import Foundation

enum Unit: ValueType {
    case none

    case bar
    case can
    case cup
    case egg
    case gram
    case internationalUnit
    case microgram
    case milligram
    case piece
    case pill
    case slice
    case tablespoon
    case teaspoon
    case whole

    case calorie
    case centimeter
    case dollar
    case gramsPerLbm
    case inch
    case kilogram
    case liter
    case percentage
    case pound
    case year


    var singularForm: String {
        switch self {
        case .none: return ""

        case .bar: return "bar"
        case .can: return "can"
        case .cup: return "cup"
        case .egg: return "egg"
        case .gram: return "gram"
        case .internationalUnit: return "IU"
        case .microgram: return "mcg"
        case .milligram: return "mg"
        case .piece: return "piece"
        case .pill: return "pill"
        case .slice: return "slice"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case .whole: return "whole"

        case .calorie: return "cal"
        case .centimeter: return "cm"
        case .dollar: return "$"
        case .gramsPerLbm: return "g/lbm"
        case .inch: return "in"
        case .kilogram: return "kg"
        case .liter: return "liter"
        case .percentage: return "%"
        case .pound: return "lb"
        case .year: return "yr"
        }
    }


    var pluralForm: String {
        switch self {
        case .none: return ""

        case .bar: return "bars"
        case .can: return "cans"
        case .cup: return "cups"
        case .egg: return "eggs"
        case .gram: return "grams"
        case .internationalUnit: return "IUs"
        case .microgram: return "mcgs"
        case .milligram: return "mgs"
        case .piece: return "pieces"
        case .pill: return "pills"
        case .slice: return "slices"
        case .tablespoon: return "tbsps"
        case .teaspoon: return "tsps"
        case .whole: return "whole"

        case .calorie: return "cals"
        case .centimeter: return "cm"
        case .dollar: return "$"
        case .gramsPerLbm: return "g/lbm"
        case .inch: return "inches"
        case .kilogram: return "kgs"
        case .liter: return "liters"
        case .percentage: return "%"
        case .pound: return "lbs"
        case .year: return "yrs"
        }
    }


    static func ingredientOptions() -> [Unit] {
        var options: [Unit] = []
        options.append(bar)
        options.append(can)
        options.append(cup)
        options.append(egg)
        options.append(gram)
        options.append(piece)
        options.append(slice)
        options.append(tablespoon)
        options.append(teaspoon)
        options.append(whole)
        return options
    }


    func formattedString(_ precision: Int) -> String {
        return String(describing: self).capitalized
    }


    func singular() -> Bool {
        return true
    }
}
