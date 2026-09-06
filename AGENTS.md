# Agent rules — the Nutrition iOS app

A SwiftUI nutrition tracker: meals, ingredients, vitamin/mineral intake, with
automatic and manual adjustments. Machine-wide rules (commit and push without
asking, install to the phone without asking, no simulator) are in
`~/src/AGENTS.md`. Seed data and the RDA table live in the sibling
`../nutrition-config` repo, not here.

Ingredients (foods, variants, brands, prices) are authored only in
`nutrition-config`, through its MCP server. The app has no ingredient
add/edit/delete screens and no label scanner; it fetches the config
(`Config/ConfigSync.swift`) from the Prep tab's pull-to-refresh or the
hamburger menu's "Refresh data", and `IngredientMgr` / `FoodMgr` reload
whenever `ConfigStore` applies a new set. Do not add in-app authoring back.

## Build, test, install

The project is XcodeGen-generated from `project.yml`; `nutrition.xcodeproj`
is gitignored, so run `xcodegen generate` after cloning. Every `xcodebuild`
needs `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` first.

Tests are the XCTest target `nutritionTests`, a characterization suite for
`MealPlanner` and the math core:

```sh
xcodebuild -project nutrition.xcodeproj -scheme nutrition \
  -destination 'platform=iOS Simulator,name=<any iPhone>' test
```

Install with the `install-to-phone` skill (`claude-base`). Two facts that
bite here and nowhere else: the scheme is lowercase `nutrition` while the
product is `Nutrition.app`, and the app declares HealthKit, so it signs with
the app-specific provisioning profile, which must contain the phone's UDID.
The skill has the failure text and the fix.

## Code conventions

- Functions top-down: main first, helpers after.
- Short-circuit in conditionals; `switch` over if-else chains.
- Models are `Codable` + `Identifiable`; managers are `ObservableObject`s with
  `@Published` state that serialize on `didSet`. Update by copying, not
  mutating.
- Persistence is `UserDefaults` with JSON, via `UserDefaultsStore`, keyed
  `profiles`, `activeProfileId`, and per-profile keys like
  `mealIngredient.<profileId>`.

Start reading at `NutritionApp.swift` (entry, dependency injection),
`Ingredients/Ingredient.swift` (the nutrition data model),
`Meal/MealIngredient.swift` (the adjustment system: Default, Manual,
Automatic states with undo), and `Profile/Profile.swift` (age and gender
based requirements).

## Data tooling

Seed data is YAML in `../nutrition-config`. Price and nutrition fetches that
feed it go through the `nutrition` plugin's `fetching-from-wholefoods` skill
(`wholefoods_fetch.py`). The local `scripts/*.py` are for one-off lookups
only; their seed `--apply` modes hard-error on purpose and stay that way:

```sh
scripts/.venv/bin/python scripts/wf_refresh.py --url "<wf-product-url>" [...]
```

**Cost is gram-based:**

```
costPerGram    = totalCost / effectiveTotalGrams   (totalGrams if > 0, else parsed from the name)
costPerServing = costPerGram × servingSize
meal-row cost  = costPerGram × (amount × consumptionGrams)
```

So `totalGrams` must be the net grams of the whole container. For pill or
capsule supplements `consumptionGrams` is grams per pill, so
`totalGrams = containerPillCount × consumptionGrams`. A placeholder like
`totalGrams: 1` makes every pill cost a whole bottle. That was a real bug.

**Never use sale prices.** Seed `totalCost` is the regular price. Whole Foods
exposes both: regular is `offerDetails.price.basisPriceAmount` when on sale,
else `priceAmount`. Reading a page by hand, take the crossed-out figure.

## Credentials

ASC keys (`ASC_KEY_ID` / `ASC_ISSUER_ID`) live in 1Password, never in `~/.env`
or a shell rc. `scripts/testflight.sh` re-execs itself under
`op run --env-file=$HOME/.config/op/env/asc.env` when they are unset, or run
`with-asc ./scripts/testflight.sh`. Never restore `source ~/.env` for ASC,
never commit a key, never paste one into chat. The full house policy is the
"API keys" section of `~/src/AGENTS.md`.
