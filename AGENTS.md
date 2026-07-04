# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a nutrition tracking application with a single component: the
**iOS SwiftUI App** (`nutrition/` directory). Vitamin/mineral RDA data
lives in the sibling `../nutrition-config` repo (`rda.yaml`), along with
the ingredient/food seed data.

The app helps users track meals, ingredients, nutritional values, and vitamin/mineral intake with automatic and manual adjustments.

## Common Commands

### iOS Development
- **Build Project**: Open `nutrition.xcodeproj` in Xcode and use Cmd+B to build
- **Run on Simulator**: Open in Xcode and use Cmd+R to run
- **Clean Build**: Product → Clean Build Folder in Xcode

## Architecture Overview

### iOS App Structure (SwiftUI + MVVM Pattern)

**Core Managers (ObservableObject pattern):**
- `IngredientMgr`: Manages food ingredients database and CRUD operations
- `MealIngredientMgr`: Handles meal composition and automatic/manual adjustments
- `AdjustmentMgr`: Manages dietary adjustments and constraints
- `ProfileMgr`: User profile and age/gender-based nutritional requirements
- `MacrosMgr`: Calculates and tracks macronutrient targets
- `VitaminMineralMgr`: Handles micronutrient tracking

**Key Data Models:**
- `Ingredient`: Comprehensive nutrition data with 20+ vitamins/minerals
- `MealIngredient`: Meal-specific ingredient with amount/adjustment tracking
- `Adjustment`: Automatic dietary adjustments with constraints
- `Profile`: User profile with age/gender-based nutrition calculations

**UI Organization:**
- `Tabs.swift`: Main tab-based navigation
- `Meal/`: Meal planning, dashboard, and macro tracking
- `Ingredients/`: Ingredient management (add/edit/list)
- `Adjustments/`: Dietary adjustment management
- `Profile/`: User profile and nutritional requirements
- `VitaminMinerals/`: Micronutrient tracking

### Data Architecture

**Persistence:**
- Uses `UserDefaults` with JSON encoding/decoding for data persistence (via `UserDefaultsStore`)
- Each manager handles its own serialization/deserialization
- Key-based storage: "profiles", "activeProfileId", and per-profile namespaced keys "mealIngredient.\<profileId>", "adjustment.\<profileId>", "foodComposite.\<profileId>"

**Adjustment System:**
- **Constants.Default**: Original state
- **Constants.Manual**: User-modified amounts
- **Constants.Automatic**: System-calculated adjustments
- Supports undo operations and state restoration

**Nutrition Calculations:**
- Age and gender-based vitamin/mineral requirements (extensive lookup tables)
- Automatic scaling based on serving sizes and consumption units
- Support for various units (grams, tablespoons, pieces, cans, etc.)

### Special Features

**OpenFoodFacts Integration:**
- API integration for ingredient lookup via EAN/barcode scanning
- Example API calls in README: `curl https://world.openfoodfacts.org/api/v0/product/{barcode}.json`

**HealthKit Integration:**
- Configured with healthkit entitlements
- Can retrieve user profile data from Health app

**Comprehensive Nutrition Database:**
- 20+ vitamins and minerals per ingredient
- Age/gender-specific DV calculations using NIH guidelines
- Support for meat planning with automatic quantity calculations

## Development Guidelines

**Code Style (from existing CLAUDE.md):**
- Functions organized top-down (main → helper functions)
- Use short-circuiting in conditionals
- Switch statements preferred over if-else chains

**SwiftUI Patterns:**
- Environment objects for data sharing between views
- ObservableObject managers with @Published properties
- Immutable struct updates (create new instances vs. mutation)
- Navigation with `NavigationView` and `StackNavigationViewStyle`

**Data Model Patterns:**
- All models implement `Codable` and `Identifiable`
- Manager classes handle CRUD operations and business logic
- Automatic serialization on data changes via `didSet`
- Copy-based updates to maintain immutability

## Key Files to Understand

- `NutritionApp.swift`: App entry point with dependency injection
- `Tabs.swift`: Main navigation structure
- `Ingredients/Ingredient.swift`: Core data model with extensive nutrition data
- `Meal/MealIngredient.swift`: Complex adjustment system implementation
- `Profile/Profile.swift`: Age/gender-based nutritional calculations

## Feature Development Areas

The README.md contains extensive feature prioritization (P0-P4) including:
- EAN scanner integration
- Enhanced ingredient search
- Cloud Kit sync and collaboration
- Advanced macro/micro nutrient tracking
- Export/import functionality

## Testing and Validation

- Automated tests: XCTest target `nutritionTests` — a characterization
  suite for `MealPlanner` and the math core (~55 tests). Run with:
  `xcodebuild -project nutrition.xcodeproj -scheme nutrition -destination 'platform=iOS Simulator,name=<any iPhone>' test`
- Manual testing via iOS Simulator
- Ingredient data verification tracked via `verified` field
- Debug logging throughout adjustment calculations

## Data Tooling

**Seed data lives in `../nutrition-config`.** Ingredient/food seed data
is YAML in the sibling `nutrition-config` repo (along with `rda.yaml`
for vitamin/mineral RDAs) — not in this repo.

**Canonical Whole Foods fetch workflow:** the `nutrition` Claude Code
plugin's `fetching-from-wholefoods` skill (`wholefoods_fetch.py`). Use
that for price/nutrition fetches that feed the seed data.

**Cost model** — ingredient cost is gram-based:

```
costPerGram    = totalCost / effectiveTotalGrams   (effectiveTotalGrams = totalGrams if > 0, else parsed from the name)
costPerServing = costPerGram × servingSize
meal-row cost  = costPerGram × (amount × consumptionGrams)
```

So **`totalGrams` must be the net grams of the whole container**. For
pill/capsule supplements `consumptionGrams` is grams *per pill*, so
`totalGrams = containerPillCount × consumptionGrams`. A placeholder
like `totalGrams: 1` makes every pill cost a whole bottle — that was a
real bug; don't reintroduce it.

> **Rule: never use sale prices.** When pulling any price (a fetch
> script, a manual page read, an Amazon listing — anything) the seed
> `totalCost` must be the **regular** price. WF exposes both: regular
> = `offerDetails.price.basisPriceAmount` when on sale, else
> `priceAmount`. If you ever read a page by hand, ignore the displayed
> sale/"current" price and use the crossed-out / "regular" figure.

**Local `scripts/*.py`** remain ONLY for one-off lookups:

```
# look up ONE (or a few) products directly; prints parsed
# price+nutrition JSON to stdout, progress to stderr (pipeable)
scripts/.venv/bin/python scripts/wf_refresh.py --url "<wf-product-url>" ["<url2>" ...]
```

Their seed-`--apply` modes intentionally hard-error with "seed data
moved to ../nutrition-config" — do not try to restore them.