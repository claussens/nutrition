# Code Overview

nutrition/app.swift




# Features

## Current P0

- Auto
  - results in comp create/etc
  - reset to default values on each pull down?

- Allow some ingredients to be set manually
  - Results in a manual override on the ingredient
  - Swipe to remove manual override (returns to default value)


- Change meal/amount while in lock



## P0

- On change of amount, highlight entire amount
- Make MealList use smart formatting so decimal values show up (olive oil 2.5)
- Ingredient search bar using crypto pattern
- Colors using crypto pattern
- API using crypto pattern
- Checkmark visual indicator that save was successful using crypto pattern
- NavBar appearance in app.swift using crypto pattern

- Save buttons only appear when data's been modified

- Meat meal adjustments: Add delete capability (to both add/edit)
- BUG: Fix ing/adj so they don't serialize on each character typed
- BUG: Disallow a duplicate named ingredient
- Serialization MVVM sample project
- Add form/field validation
  - How to validate at add time given publisher is on the View Model?
- Edit/move and Edit/delete doesn't work
  - BUG: onDelete brings up swipe menu now vs deleting, dig into why



## P1

- Change toggle bg color to yellow/...
- Animate gauges
- Inactive -> active, when locked, should add compensation
- Enable Caden profile (profiles in general)
- Next/Next/Next field ...
- Collapsible: https://betterprogramming.pub/how-to-write-a-collapsible-expandable-view-for-your-swiftui-app-d4a47fe8cb52
- Cloud Kit Extending/Collaboration (for logging):
  - https://swiftwithmajid.com/2022/03/29/zone-sharing-in-cloudkit
  - https://swiftwithmajid.com/2022/03/22/getting-started-with-cloudkit
- Consider changing consumption unit to preparation unit
- Variable picker style type
- Add health zones
- Allow meal ingredient update to hit return and go back to meal list
- Rationalize why setNetCarbsMax works diff than setWeight/etc for Profile.swift
- Enable profile info to be retrieved from health kit or not (optional)
- Reset all (or one) bases to default amount (Reset single bases to default right right hand menu)
- Display brand on hover?
- Populate brands
- Populate retail
- Populate $/gram
- Add vitamins/minerals
- Custom tab bar
- Custom nav bar
- Hover effects
- Capitalize each word of ingredients
- Custom keyboard to support negative numbers
  - https://developer.apple.com/documentation/uikit/keyboards_and_input/creating_a_custom_keyboard
- Alternative BMR:
  Harris-Benedict               if(Sex="Male", 66+(6.2*Weight)+(12.7*Height)-(6.76*Age), 655+(4.35*Weight)+(4.7*Height)-(4.7*Age))
  Harris-Benedict-Revised       =if(Sex="Male", (88.362 + (13.397 * WeightKG) + (4.799 * HeightCM) - (5.677 * Age)), 447.593 + (9.247 * WeightKG) + (3.098 * Height) - (4.33 * Age))
  Katch-McArdle                 =370+(21.6*LeanBodyMassKG)
  Cunningham                    =500+(22*LeanBodyMassKG)
- Ingredient URLs
  Link(destination: URL(string: "https://www.apple.com")!) {
    Image(systemName: "link.circle.fill")
        .font(.largeTitle)
}
https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures


## P2

- Filter out invalid characters
- Make progressbar generic
- Fix date picker so it sizes properly
- Splash screen
- Remove 0s from int/double input fields
- Filter ingredients based on fat, carbs, protein, alpha, ..


## P3

- Tuna freeze out dates
- Fix delete swipe action on lists
- Quick actions (icon menu)


## P4

- Shake gesture - not availabel yet in the SwifUI framework
  https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures
- Fix all previews
- DatePicker/Sheet https://github.com/shaotaoliu/SwiftUI.DatePickerTextField/tree/main/DatePickerTextField
- Add No Item views
- Logging
- export/import yaml/json



## APIs/DBs

{
    "code": "0099482402891",
    "product": {
        "_id": "0099482402891",
        "_keywords": [
            "and",
            "vegetarian",
            "plant-based",
            "fruit",
            "whole",
            "vegetable",
            "based",
            "broccoli",
            "vegan",
            "market",
            "beverage",
            "food",
            "frozen",
            "floret"
        ],
        "added_countries_tags": [],
        "additives_n": 0,
        "additives_old_n": 0,
        "additives_old_tags": [],
        "additives_original_tags": [],
        "additives_tags": [],
        "allergens": "",
        "allergens_from_ingredients": "",
        "allergens_from_user": "(en) ",
        "allergens_hierarchy": [],
        "allergens_lc": "en",
        "allergens_tags": [],
        "amino_acids_tags": [],
        "brand_owner": "Whole Foods Market, Inc.",
        "brand_owner_imported": "Whole Foods Market, Inc.",
        "brands": "Whole Foods Market",
        "brands_tags": [
            "whole-foods-market"
        ],
        "categories": "Plant-based foods and beverages, Plant-based foods, Fruits and vegetables based foods, Frozen foods, Vegetables based foods, Frozen plant-based foods, Frozen vegetables, Broccoli",
        "categories_hierarchy": [
            "en:plant-based-foods-and-beverages",
            "en:plant-based-foods",
            "en:fruits-and-vegetables-based-foods",
            "en:frozen-foods",
            "en:vegetables-based-foods",
            "en:frozen-plant-based-foods",
            "en:frozen-vegetables",
            "en:broccoli"
        ],
        "categories_imported": "Plant-based foods and beverages, Plant-based foods, Fruits and vegetables based foods, Frozen foods, Vegetables based foods, Frozen plant-based foods, Frozen vegetables",
        "categories_lc": "en",
        "categories_old": "Plant-based foods and beverages, Plant-based foods, Fruits and vegetables based foods, Frozen foods, Vegetables based foods, Frozen plant-based foods, Frozen vegetables, Broccoli",
        "categories_properties": {
            "agribalyse_food_code:en": "20057",
            "ciqual_food_code:en": "20057"
        },
        "categories_properties_tags": [
            "all-products",
            "categories-known",
            "agribalyse-food-code-20057",
            "agribalyse-food-code-known",
            "agribalyse-proxy-food-code-unknown",
            "ciqual-food-code-20057",
            "ciqual-food-code-known",
            "agribalyse-known",
            "agribalyse-20057"
        ],
        "categories_tags": [
            "en:plant-based-foods-and-beverages",
            "en:plant-based-foods",
            "en:fruits-and-vegetables-based-foods",
            "en:frozen-foods",
            "en:vegetables-based-foods",
            "en:frozen-plant-based-foods",
            "en:frozen-vegetables",
            "en:broccoli"
        ],
        "category_properties": {},
        "checkers_tags": [],
        "ciqual_food_name_tags": [
            "unknown"
        ],
        "cities_tags": [],
        "code": "0099482402891",
        "codes_tags": [
            "code-13",
            "0099482402xxx",
            "009948240xxxx",
            "00994824xxxxx",
            "0099482xxxxxx",
            "009948xxxxxxx",
            "00994xxxxxxxx",
            "0099xxxxxxxxx",
            "009xxxxxxxxxx",
            "00xxxxxxxxxxx",
            "0xxxxxxxxxxxx"
        ],
        "compared_to_category": "en:broccoli",
        "complete": 0,
        "completeness": 0.5875,
        "correctors_tags": [
            "bredowmax",
            "org-database-usda",
            "yuka.sY2b0xO6T85zoF3NwEKvlhFqcdbugjCVEDvgtFezn9HXD534b993_6LaM6g",
            "kiliweb"
        ],
        "countries": "United States",
        "countries_hierarchy": [
            "en:united-states"
        ],
        "countries_imported": "United States",
        "countries_lc": "en",
        "countries_tags": [
            "en:united-states"
        ],
        "created_t": 1583693547,
        "creator": "bredowmax",
        "data_quality_bugs_tags": [],
        "data_quality_errors_tags": [],
        "data_quality_info_tags": [
            "en:no-packaging-data",
            "en:ingredients-percent-analysis-ok",
            "en:all-but-one-ingredient-with-specified-percent"
        ],
        "data_quality_tags": [
            "en:no-packaging-data",
            "en:ingredients-percent-analysis-ok",
            "en:all-but-one-ingredient-with-specified-percent",
            "en:nutrition-value-under-0-1-g-salt",
            "en:serving-quantity-defined-but-quantity-undefined",
            "en:ecoscore-origins-of-ingredients-origins-are-100-percent-unknown",
            "en:ecoscore-packaging-packaging-data-missing",
            "en:ecoscore-production-system-no-label"
        ],
        "data_quality_warnings_tags": [
            "en:nutrition-value-under-0-1-g-salt",
            "en:serving-quantity-defined-but-quantity-undefined",
            "en:ecoscore-origins-of-ingredients-origins-are-100-percent-unknown",
            "en:ecoscore-packaging-packaging-data-missing",
            "en:ecoscore-production-system-no-label"
        ],
        "data_sources": "Databases, database-usda, App - yuka, Apps",
        "data_sources_imported": "Databases, database-usda",
        "data_sources_tags": [
            "databases",
            "database-usda",
            "app-yuka",
            "apps"
        ],
        "debug_param_sorted_langs": [
            "en"
        ],
        "downgraded": "non_recyclable_and_non_biodegradable_materials",
        "ecoscore_data": {
            "adjustments": {
                "origins_of_ingredients": {
                    "aggregated_origins": [
                        {
                            "origin": "en:unknown",
                            "percent": 100
                        }
                    ],
                    "epi_score": 0,
                    "epi_value": -5,
                    "origins_from_origins_field": [
                        "en:unknown"
                    ],
                    "transportation_scores": {
                        "ad": 0,
                        "al": 0,
                        "at": 0,
                        "ax": 0,
                        "ba": 0,
                        "be": 0,
                        "bg": 0,
                        "ch": 0,
                        "cy": 0,
                        "cz": 0,
                        "de": 0,
                        "dk": 0,
                        "dz": 0,
                        "ee": 0,
                        "eg": 0,
                        "es": 0,
                        "fi": 0,
                        "fo": 0,
                        "fr": 0,
                        "gg": 0,
                        "gi": 0,
                        "gr": 0,
                        "hr": 0,
                        "hu": 0,
                        "ie": 0,
                        "il": 0,
                        "im": 0,
                        "is": 0,
                        "it": 0,
                        "je": 0,
                        "lb": 0,
                        "li": 0,
                        "lt": 0,
                        "lu": 0,
                        "lv": 0,
                        "ly": 0,
                        "ma": 0,
                        "mc": 0,
                        "md": 0,
                        "me": 0,
                        "mk": 0,
                        "mt": 0,
                        "nl": 0,
                        "no": 0,
                        "pl": 0,
                        "ps": 0,
                        "pt": 0,
                        "ro": 0,
                        "rs": 0,
                        "se": 0,
                        "si": 0,
                        "sj": 0,
                        "sk": 0,
                        "sm": 0,
                        "sy": 0,
                        "tn": 0,
                        "tr": 0,
                        "ua": 0,
                        "uk": 0,
                        "us": 0,
                        "va": 0,
                        "world": 0,
                        "xk": 0
                    },
                    "transportation_values": {
                        "ad": 0,
                        "al": 0,
                        "at": 0,
                        "ax": 0,
                        "ba": 0,
                        "be": 0,
                        "bg": 0,
                        "ch": 0,
                        "cy": 0,
                        "cz": 0,
                        "de": 0,
                        "dk": 0,
                        "dz": 0,
                        "ee": 0,
                        "eg": 0,
                        "es": 0,
                        "fi": 0,
                        "fo": 0,
                        "fr": 0,
                        "gg": 0,
                        "gi": 0,
                        "gr": 0,
                        "hr": 0,
                        "hu": 0,
                        "ie": 0,
                        "il": 0,
                        "im": 0,
                        "is": 0,
                        "it": 0,
                        "je": 0,
                        "lb": 0,
                        "li": 0,
                        "lt": 0,
                        "lu": 0,
                        "lv": 0,
                        "ly": 0,
                        "ma": 0,
                        "mc": 0,
                        "md": 0,
                        "me": 0,
                        "mk": 0,
                        "mt": 0,
                        "nl": 0,
                        "no": 0,
                        "pl": 0,
                        "ps": 0,
                        "pt": 0,
                        "ro": 0,
                        "rs": 0,
                        "se": 0,
                        "si": 0,
                        "sj": 0,
                        "sk": 0,
                        "sm": 0,
                        "sy": 0,
                        "tn": 0,
                        "tr": 0,
                        "ua": 0,
                        "uk": 0,
                        "us": 0,
                        "va": 0,
                        "world": 0,
                        "xk": 0
                    },
                    "values": {
                        "ad": -5,
                        "al": -5,
                        "at": -5,
                        "ax": -5,
                        "ba": -5,
                        "be": -5,
                        "bg": -5,
                        "ch": -5,
                        "cy": -5,
                        "cz": -5,
                        "de": -5,
                        "dk": -5,
                        "dz": -5,
                        "ee": -5,
                        "eg": -5,
                        "es": -5,
                        "fi": -5,
                        "fo": -5,
                        "fr": -5,
                        "gg": -5,
                        "gi": -5,
                        "gr": -5,
                        "hr": -5,
                        "hu": -5,
                        "ie": -5,
                        "il": -5,
                        "im": -5,
                        "is": -5,
                        "it": -5,
                        "je": -5,
                        "lb": -5,
                        "li": -5,
                        "lt": -5,
                        "lu": -5,
                        "lv": -5,
                        "ly": -5,
                        "ma": -5,
                        "mc": -5,
                        "md": -5,
                        "me": -5,
                        "mk": -5,
                        "mt": -5,
                        "nl": -5,
                        "no": -5,
                        "pl": -5,
                        "ps": -5,
                        "pt": -5,
                        "ro": -5,
                        "rs": -5,
                        "se": -5,
                        "si": -5,
                        "sj": -5,
                        "sk": -5,
                        "sm": -5,
                        "sy": -5,
                        "tn": -5,
                        "tr": -5,
                        "ua": -5,
                        "uk": -5,
                        "us": -5,
                        "va": -5,
                        "world": -5,
                        "xk": -5
                    },
                    "warning": "origins_are_100_percent_unknown"
                },
                "packaging": {
                    "non_recyclable_and_non_biodegradable_materials": 1,
                    "value": -15,
                    "warning": "packaging_data_missing"
                },
                "production_system": {
                    "labels": [],
                    "value": 0,
                    "warning": "no_label"
                },
                "threatened_species": {}
            },
            "agribalyse": {
                "agribalyse_food_code": "20057",
                "co2_agriculture": 0.47868232,
                "co2_consumption": 0.012317297,
                "co2_distribution": 0.047418395,
                "co2_packaging": 0,
                "co2_processing": 0,
                "co2_total": 0.67898428,
                "co2_transportation": 0.14056627,
                "code": "20057",
                "dqr": "2.49",
                "ef_agriculture": 0.055641973,
                "ef_consumption": 0.00052192787,
                "ef_distribution": 0.015653825,
                "ef_packaging": 0,
                "ef_processing": 0,
                "ef_total": 0.082753501,
                "ef_transportation": 0.010935776,
                "is_beverage": 0,
                "name_en": "Broccoli, raw",
                "name_fr": "Brocoli, cru",
                "score": 98
            },
            "grade": "b",
            "grades": {
                "ad": "b",
                "al": "b",
                "at": "b",
                "ax": "b",
                "ba": "b",
                "be": "b",
                "bg": "b",
                "ch": "b",
                "cy": "b",
                "cz": "b",
                "de": "b",
                "dk": "b",
                "dz": "b",
                "ee": "b",
                "eg": "b",
                "es": "b",
                "fi": "b",
                "fo": "b",
                "fr": "b",
                "gg": "b",
                "gi": "b",
                "gr": "b",
                "hr": "b",
                "hu": "b",
                "ie": "b",
                "il": "b",
                "im": "b",
                "is": "b",
                "it": "b",
                "je": "b",
                "lb": "b",
                "li": "b",
                "lt": "b",
                "lu": "b",
                "lv": "b",
                "ly": "b",
                "ma": "b",
                "mc": "b",
                "md": "b",
                "me": "b",
                "mk": "b",
                "mt": "b",
                "nl": "b",
                "no": "b",
                "pl": "b",
                "ps": "b",
                "pt": "b",
                "ro": "b",
                "rs": "b",
                "se": "b",
                "si": "b",
                "sj": "b",
                "sk": "b",
                "sm": "b",
                "sy": "b",
                "tn": "b",
                "tr": "b",
                "ua": "b",
                "uk": "b",
                "us": "b",
                "va": "b",
                "world": "b",
                "xk": "b"
            },
            "missing": {
                "labels": 1,
                "origins": 1,
                "packagings": 1
            },
            "missing_data_warning": 1,
            "missing_key_data": 1,
            "score": 78,
            "scores": {
                "ad": 78,
                "al": 78,
                "at": 78,
                "ax": 78,
                "ba": 78,
                "be": 78,
                "bg": 78,
                "ch": 78,
                "cy": 78,
                "cz": 78,
                "de": 78,
                "dk": 78,
                "dz": 78,
                "ee": 78,
                "eg": 78,
                "es": 78,
                "fi": 78,
                "fo": 78,
                "fr": 78,
                "gg": 78,
                "gi": 78,
                "gr": 78,
                "hr": 78,
                "hu": 78,
                "ie": 78,
                "il": 78,
                "im": 78,
                "is": 78,
                "it": 78,
                "je": 78,
                "lb": 78,
                "li": 78,
                "lt": 78,
                "lu": 78,
                "lv": 78,
                "ly": 78,
                "ma": 78,
                "mc": 78,
                "md": 78,
                "me": 78,
                "mk": 78,
                "mt": 78,
                "nl": 78,
                "no": 78,
                "pl": 78,
                "ps": 78,
                "pt": 78,
                "ro": 78,
                "rs": 78,
                "se": 78,
                "si": 78,
                "sj": 78,
                "sk": 78,
                "sm": 78,
                "sy": 78,
                "tn": 78,
                "tr": 78,
                "ua": 78,
                "uk": 78,
                "us": 78,
                "va": 78,
                "world": 78,
                "xk": 78
            },
            "status": "known"
        },
        "ecoscore_grade": "b",
        "ecoscore_score": 78,
        "ecoscore_tags": [
            "b"
        ],
        "editors_tags": [
            "org-database-usda",
            "kiliweb",
            "yuka.sY2b0xO6T85zoF3NwEKvlhFqcdbugjCVEDvgtFezn9HXD534b993_6LaM6g",
            "bredowmax",
            "roboto-app"
        ],
        "emb_codes": "",
        "emb_codes_tags": [],
        "entry_dates_tags": [
            "2020-03-08",
            "2020-03",
            "2020"
        ],
        "expiration_date": "",
        "food_groups": "en:vegetables",
        "food_groups_tags": [
            "en:fruits-and-vegetables",
            "en:vegetables"
        ],
        "generic_name": "",
        "generic_name_en": "",
        "id": "0099482402891",
        "image_front_small_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.200.jpg",
        "image_front_thumb_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.100.jpg",
        "image_front_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.400.jpg",
        "image_ingredients_small_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.200.jpg",
        "image_ingredients_thumb_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.100.jpg",
        "image_ingredients_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.400.jpg",
        "image_nutrition_small_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.200.jpg",
        "image_nutrition_thumb_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.100.jpg",
        "image_nutrition_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.400.jpg",
        "image_small_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.200.jpg",
        "image_thumb_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.100.jpg",
        "image_url": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.400.jpg",
        "images": {
            "1": {
                "sizes": {
                    "100": {
                        "h": 100,
                        "w": 75
                    },
                    "400": {
                        "h": 400,
                        "w": 300
                    },
                    "full": {
                        "h": 4032,
                        "w": 3024
                    }
                },
                "uploaded_t": 1583693548,
                "uploader": "bredowmax"
            },
            "2": {
                "sizes": {
                    "100": {
                        "h": 100,
                        "w": 75
                    },
                    "400": {
                        "h": 400,
                        "w": 300
                    },
                    "full": {
                        "h": 4032,
                        "w": 3024
                    }
                },
                "uploaded_t": 1583693550,
                "uploader": "bredowmax"
            },
            "3": {
                "sizes": {
                    "100": {
                        "h": 100,
                        "w": 75
                    },
                    "400": {
                        "h": 400,
                        "w": 300
                    },
                    "full": {
                        "h": 4032,
                        "w": 3024
                    }
                },
                "uploaded_t": 1583693551,
                "uploader": "bredowmax"
            },
            "4": {
                "sizes": {
                    "100": {
                        "h": 100,
                        "w": 75
                    },
                    "400": {
                        "h": 400,
                        "w": 300
                    },
                    "full": {
                        "h": 4032,
                        "w": 3024
                    }
                },
                "uploaded_t": 1583693552,
                "uploader": "bredowmax"
            },
            "5": {
                "sizes": {
                    "100": {
                        "h": 67,
                        "w": 100
                    },
                    "400": {
                        "h": 268,
                        "w": 400
                    },
                    "full": {
                        "h": 930,
                        "w": 1390
                    }
                },
                "uploaded_t": 1631393661,
                "uploader": "kiliweb"
            },
            "6": {
                "sizes": {
                    "100": {
                        "h": 23,
                        "w": 100
                    },
                    "400": {
                        "h": 92,
                        "w": 400
                    },
                    "full": {
                        "h": 245,
                        "w": 1069
                    }
                },
                "uploaded_t": 1631393663,
                "uploader": "kiliweb"
            },
            "front_en": {
                "angle": 0,
                "coordinates_image_size": "full",
                "geometry": "0x0--1--1",
                "imgid": "5",
                "normalize": null,
                "rev": "16",
                "sizes": {
                    "100": {
                        "h": 67,
                        "w": 100
                    },
                    "200": {
                        "h": 134,
                        "w": 200
                    },
                    "400": {
                        "h": 268,
                        "w": 400
                    },
                    "full": {
                        "h": 930,
                        "w": 1390
                    }
                },
                "white_magic": null,
                "x1": "-1",
                "x2": "-1",
                "y1": "-1",
                "y2": "-1"
            },
            "ingredients_en": {
                "angle": "0",
                "geometry": "764x184-1111-1607",
                "imgid": "4",
                "normalize": "false",
                "rev": "9",
                "sizes": {
                    "100": {
                        "h": 24,
                        "w": 100
                    },
                    "200": {
                        "h": 48,
                        "w": 200
                    },
                    "400": {
                        "h": 96,
                        "w": 400
                    },
                    "full": {
                        "h": 184,
                        "w": 764
                    }
                },
                "white_magic": "false",
                "x1": "110.28125",
                "x2": "186.08203125",
                "y1": "159.43359375",
                "y2": "177.70703125"
            },
            "nutrition_en": {
                "angle": 0,
                "coordinates_image_size": "full",
                "geometry": "0x0--1--1",
                "imgid": "6",
                "normalize": null,
                "rev": "18",
                "sizes": {
                    "100": {
                        "h": 23,
                        "w": 100
                    },
                    "200": {
                        "h": 46,
                        "w": 200
                    },
                    "400": {
                        "h": 92,
                        "w": 400
                    },
                    "full": {
                        "h": 245,
                        "w": 1069
                    }
                },
                "white_magic": null,
                "x1": "-1",
                "x2": "-1",
                "y1": "-1",
                "y2": "-1"
            }
        },
        "informers_tags": [
            "bredowmax",
            "roboto-app",
            "org-database-usda"
        ],
        "ingredients": [
            {
                "id": "en:broccoli",
                "percent_estimate": 100,
                "percent_max": 100,
                "percent_min": 100,
                "rank": 1,
                "text": "BROCCOLI",
                "vegan": "yes",
                "vegetarian": "yes"
            }
        ],
        "ingredients_analysis": {},
        "ingredients_analysis_tags": [
            "en:palm-oil-free",
            "en:vegan",
            "en:vegetarian"
        ],
        "ingredients_from_or_that_may_be_from_palm_oil_n": 0,
        "ingredients_from_palm_oil_n": 0,
        "ingredients_from_palm_oil_tags": [],
        "ingredients_hierarchy": [
            "en:broccoli",
            "en:vegetable"
        ],
        "ingredients_n": 1,
        "ingredients_n_tags": [
            "1",
            "1-10"
        ],
        "ingredients_original_tags": [
            "en:broccoli"
        ],
        "ingredients_percent_analysis": 1,
        "ingredients_tags": [
            "en:broccoli",
            "en:vegetable"
        ],
        "ingredients_text": "BROCCOLI.",
        "ingredients_text_en": "BROCCOLI.",
        "ingredients_text_en_imported": "Broccoli.",
        "ingredients_text_with_allergens": "BROCCOLI.",
        "ingredients_text_with_allergens_en": "BROCCOLI.",
        "ingredients_that_may_be_from_palm_oil_n": 0,
        "ingredients_that_may_be_from_palm_oil_tags": [],
        "ingredients_with_specified_percent_n": 0,
        "ingredients_with_specified_percent_sum": 0,
        "ingredients_with_unspecified_percent_n": 1,
        "ingredients_with_unspecified_percent_sum": 100,
        "interface_version_created": "import_csv_file - version 2019/09/17",
        "interface_version_modified": "20150316.jqm2",
        "known_ingredients_n": 2,
        "labels": "Vegetarian,Vegan",
        "labels_hierarchy": [
            "en:vegetarian",
            "en:vegan"
        ],
        "labels_lc": "en",
        "labels_tags": [
            "en:vegetarian",
            "en:vegan"
        ],
        "lang": "en",
        "languages": {
            "en:english": 5
        },
        "languages_codes": {
            "en": 5
        },
        "languages_hierarchy": [
            "en:english"
        ],
        "languages_tags": [
            "en:english",
            "en:1"
        ],
        "last_edit_dates_tags": [
            "2021-09-11",
            "2021-09",
            "2021"
        ],
        "last_editor": "kiliweb",
        "last_image_dates_tags": [
            "2021-09-11",
            "2021-09",
            "2021"
        ],
        "last_image_t": 1631393663,
        "last_modified_by": "kiliweb",
        "last_modified_t": 1631393663,
        "lc": "en",
        "lc_imported": "en",
        "link": "",
        "main_countries_tags": [],
        "manufacturing_places": "",
        "manufacturing_places_tags": [],
        "max_imgid": "6",
        "minerals_tags": [],
        "misc_tags": [
            "en:nutrition-fruits-vegetables-nuts-from-category",
            "en:nutrition-fruits-vegetables-nuts-from-category-en-vegetables-based-foods",
            "en:nutrition-all-nutriscore-values-known",
            "en:nutriscore-computed",
            "en:main-countries-no-scans",
            "en:ecoscore-extended-data-not-computed",
            "en:ecoscore-missing-data-warning",
            "en:ecoscore-missing-data-labels",
            "en:ecoscore-missing-data-origins",
            "en:ecoscore-missing-data-packagings",
            "en:ecoscore-missing-data-no-packagings",
            "en:ecoscore-computed"
        ],
        "no_nutrition_data": "",
        "nova_group": 1,
        "nova_group_debug": "",
        "nova_group_tags": [
            "not-applicable"
        ],
        "nova_groups": "1",
        "nova_groups_tags": [
            "en:1-unprocessed-or-minimally-processed-foods"
        ],
        "nucleotides_tags": [],
        "nutrient_levels": {
            "fat": "low",
            "salt": "low",
            "saturated-fat": "low",
            "sugars": "low"
        },
        "nutrient_levels_tags": [
            "en:fat-in-low-quantity",
            "en:saturated-fat-in-low-quantity",
            "en:sugars-in-low-quantity",
            "en:salt-in-low-quantity"
        ],
        "nutriments": {
            "calcium": 0.024,
            "calcium_100g": 0.024,
            "calcium_serving": 0.0204,
            "calcium_unit": "mg",
            "calcium_value": 24,
            "carbohydrates": 4.7058823529412,
            "carbohydrates_100g": 4.7058823529412,
            "carbohydrates_serving": 4,
            "carbohydrates_unit": "g",
            "carbohydrates_value": 4.7058823529412,
            "cholesterol": 0,
            "cholesterol_100g": 0,
            "cholesterol_serving": 0,
            "cholesterol_unit": "mg",
            "cholesterol_value": 0,
            "energy": 98,
            "energy-kcal": 23.529411764706,
            "energy-kcal_100g": 23.529411764706,
            "energy-kcal_serving": 20,
            "energy-kcal_unit": "kcal",
            "energy-kcal_value": 23.529411764706,
            "energy_100g": 98,
            "energy_serving": 83.3,
            "energy_unit": "kcal",
            "energy_value": 23.529411764706,
            "fat": 0,
            "fat_100g": 0,
            "fat_serving": 0,
            "fat_unit": "g",
            "fat_value": 0,
            "fiber": 2.4,
            "fiber_100g": 2.4,
            "fiber_serving": 2.04,
            "fiber_unit": "g",
            "fiber_value": 2.4,
            "fruits-vegetables-nuts-estimate-from-ingredients_100g": 100,
            "fruits-vegetables-nuts-estimate-from-ingredients_serving": 100,
            "iron": 0,
            "iron_100g": 0,
            "iron_serving": 0,
            "iron_unit": "mg",
            "iron_value": 0,
            "nova-group": 1,
            "nova-group_100g": 1,
            "nova-group_serving": 1,
            "nutrition-score-fr": -8,
            "nutrition-score-fr_100g": -8,
            "proteins": 2.3529411764706,
            "proteins_100g": 2.3529411764706,
            "proteins_serving": 2,
            "proteins_unit": "g",
            "proteins_value": 2.3529411764706,
            "salt": 0.058823529411765,
            "salt_100g": 0.058823529411765,
            "salt_serving": 0.05,
            "salt_unit": "g",
            "salt_value": 0.058823529411765,
            "saturated-fat": 0,
            "saturated-fat_100g": 0,
            "saturated-fat_serving": 0,
            "saturated-fat_unit": "g",
            "saturated-fat_value": 0,
            "sodium": 0.023529411764706,
            "sodium_100g": 0.023529411764706,
            "sodium_serving": 0.02,
            "sodium_unit": "g",
            "sodium_value": 0.023529411764706,
            "sugars": 1.1764705882353,
            "sugars_100g": 1.1764705882353,
            "sugars_serving": 1,
            "sugars_unit": "g",
            "sugars_value": 1.1764705882353,
            "trans-fat": 0,
            "trans-fat_100g": 0,
            "trans-fat_serving": 0,
            "trans-fat_unit": "g",
            "trans-fat_value": 0,
            "vitamin-a": 0,
            "vitamin-a_100g": 0,
            "vitamin-a_serving": 0,
            "vitamin-a_unit": "IU",
            "vitamin-a_value": 0,
            "vitamin-c": 0.0353,
            "vitamin-c_100g": 0.0353,
            "vitamin-c_serving": 0.03,
            "vitamin-c_unit": "mg",
            "vitamin-c_value": 35.3
        },
        "nutriscore_data": {
            "energy": 98,
            "energy_points": 0,
            "energy_value": 98,
            "fiber": 2.4,
            "fiber_points": 2,
            "fiber_value": 2.4,
            "fruits_vegetables_nuts_colza_walnut_olive_oils": 85,
            "fruits_vegetables_nuts_colza_walnut_olive_oils_points": 5,
            "fruits_vegetables_nuts_colza_walnut_olive_oils_value": 85,
            "grade": "a",
            "is_beverage": 0,
            "is_cheese": 0,
            "is_fat": 0,
            "is_water": 0,
            "negative_points": 0,
            "positive_points": 8,
            "proteins": 2.3529411764706,
            "proteins_points": 1,
            "proteins_value": 2.35,
            "saturated_fat": 0,
            "saturated_fat_points": 0,
            "saturated_fat_ratio": 0,
            "saturated_fat_ratio_points": 0,
            "saturated_fat_ratio_value": 0,
            "saturated_fat_value": 0,
            "score": -8,
            "sodium": 23.529411764706,
            "sodium_points": 0,
            "sodium_value": 23.5,
            "sugars": 1.1764705882353,
            "sugars_points": 0,
            "sugars_value": 1.18
        },
        "nutriscore_grade": "a",
        "nutriscore_score": -8,
        "nutriscore_score_opposite": 8,
        "nutrition_data": "on",
        "nutrition_data_per": "100g",
        "nutrition_data_per_imported": "100g",
        "nutrition_data_prepared": "",
        "nutrition_data_prepared_per": "100g",
        "nutrition_data_prepared_per_imported": "100g",
        "nutrition_grade_fr": "a",
        "nutrition_grades": "a",
        "nutrition_grades_tags": [
            "a"
        ],
        "nutrition_score_beverage": 0,
        "nutrition_score_warning_fruits_vegetables_nuts_from_category": "en:vegetables-based-foods",
        "nutrition_score_warning_fruits_vegetables_nuts_from_category_value": 85,
        "obsolete": "",
        "obsolete_since_date": "",
        "origins": "",
        "origins_hierarchy": [],
        "origins_lc": "en",
        "origins_old": "",
        "origins_tags": [],
        "other_nutritional_substances_tags": [],
        "packaging": "",
        "packaging_hierarchy": [],
        "packaging_lc": "en",
        "packaging_old": "",
        "packaging_tags": [],
        "packagings": [],
        "photographers_tags": [
            "bredowmax",
            "kiliweb"
        ],
        "pnns_groups_1": "Fruits and vegetables",
        "pnns_groups_1_tags": [
            "fruits-and-vegetables",
            "known"
        ],
        "pnns_groups_2": "Vegetables",
        "pnns_groups_2_tags": [
            "vegetables",
            "known"
        ],
        "popularity_key": 8,
        "product_name": "Broccoli florets",
        "product_name_en": "Broccoli florets",
        "product_name_en_imported": "Broccoli florets",
        "purchase_places": "",
        "purchase_places_tags": [],
        "quantity": "",
        "removed_countries_tags": [],
        "rev": 18,
        "selected_images": {
            "front": {
                "display": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.400.jpg"
                },
                "small": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.200.jpg"
                },
                "thumb": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/front_en.16.100.jpg"
                }
            },
            "ingredients": {
                "display": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.400.jpg"
                },
                "small": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.200.jpg"
                },
                "thumb": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/ingredients_en.9.100.jpg"
                }
            },
            "nutrition": {
                "display": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.400.jpg"
                },
                "small": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.200.jpg"
                },
                "thumb": {
                    "en": "https://images.openfoodfacts.org/images/products/009/948/240/2891/nutrition_en.18.100.jpg"
                }
            }
        },
        "serving_quantity": "85",
        "serving_size": "1 cup (85 g)",
        "serving_size_imported": "1 cup (85 g)",
        "sortkey": 1587671020,
        "sources": [
            {
                "fields": [
                    "product_name_en",
                    "categories",
                    "brand_owner",
                    "data_sources",
                    "serving_size",
                    "nutrients.calcium_unit",
                    "nutrients.calcium_value",
                    "nutrients.carbohydrates_unit",
                    "nutrients.carbohydrates_value",
                    "nutrients.cholesterol_unit",
                    "nutrients.cholesterol_value",
                    "nutrients.energy_unit",
                    "nutrients.energy_value",
                    "nutrients.energy-kcal_unit",
                    "nutrients.energy-kcal_value",
                    "nutrients.fat_unit",
                    "nutrients.fat_value",
                    "nutrients.fiber_unit",
                    "nutrients.fiber_value",
                    "nutrients.iron_unit",
                    "nutrients.iron_value",
                    "nutrients.proteins_unit",
                    "nutrients.proteins_value",
                    "nutrients.salt_unit",
                    "nutrients.salt_value",
                    "nutrients.saturated-fat_unit",
                    "nutrients.saturated-fat_value",
                    "nutrients.sugars_unit",
                    "nutrients.sugars_value",
                    "nutrients.trans-fat_unit",
                    "nutrients.trans-fat_value",
                    "nutrients.vitamin-a_unit",
                    "nutrients.vitamin-a_value",
                    "nutrients.vitamin-c_unit",
                    "nutrients.vitamin-c_value"
                ],
                "id": "database-usda",
                "images": [],
                "import_t": 1587671020,
                "manufacturer": null,
                "name": "database-usda",
                "url": null
            }
        ],
        "sources_fields": {
            "org-database-usda": {
                "available_date": "2019-04-17T00:00:00Z",
                "fdc_category": "Frozen Vegetables",
                "fdc_data_source": "LI",
                "fdc_id": "705082",
                "modified_date": "2019-04-17T00:00:00Z",
                "publication_date": "2019-12-06T00:00:00Z"
            }
        },
        "states": "en:to-be-completed, en:nutrition-facts-completed, en:ingredients-completed, en:expiration-date-to-be-completed, en:packaging-code-to-be-completed, en:characteristics-to-be-completed, en:origins-to-be-completed, en:categories-completed, en:brands-completed, en:packaging-to-be-completed, en:quantity-to-be-completed, en:product-name-completed, en:photos-to-be-validated, en:packaging-photo-to-be-selected, en:nutrition-photo-selected, en:ingredients-photo-selected, en:front-photo-selected, en:photos-uploaded",
        "states_hierarchy": [
            "en:to-be-completed",
            "en:nutrition-facts-completed",
            "en:ingredients-completed",
            "en:expiration-date-to-be-completed",
            "en:packaging-code-to-be-completed",
            "en:characteristics-to-be-completed",
            "en:origins-to-be-completed",
            "en:categories-completed",
            "en:brands-completed",
            "en:packaging-to-be-completed",
            "en:quantity-to-be-completed",
            "en:product-name-completed",
            "en:photos-to-be-validated",
            "en:packaging-photo-to-be-selected",
            "en:nutrition-photo-selected",
            "en:ingredients-photo-selected",
            "en:front-photo-selected",
            "en:photos-uploaded"
        ],
        "states_tags": [
            "en:to-be-completed",
            "en:nutrition-facts-completed",
            "en:ingredients-completed",
            "en:expiration-date-to-be-completed",
            "en:packaging-code-to-be-completed",
            "en:characteristics-to-be-completed",
            "en:origins-to-be-completed",
            "en:categories-completed",
            "en:brands-completed",
            "en:packaging-to-be-completed",
            "en:quantity-to-be-completed",
            "en:product-name-completed",
            "en:photos-to-be-validated",
            "en:packaging-photo-to-be-selected",
            "en:nutrition-photo-selected",
            "en:ingredients-photo-selected",
            "en:front-photo-selected",
            "en:photos-uploaded"
        ],
        "stores": "Whole Foods",
        "stores_tags": [
            "whole-foods"
        ],
        "traces": "",
        "traces_from_ingredients": "",
        "traces_from_user": "(en) ",
        "traces_hierarchy": [],
        "traces_lc": "en",
        "traces_tags": [],
        "unknown_ingredients_n": 0,
        "unknown_nutrients_tags": [],
        "update_key": "ing20220322",
        "vitamins_tags": []
    },
    "status": 1,
    "status_verbose": "product found"
}
