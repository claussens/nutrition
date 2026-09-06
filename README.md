# Nutrition

A SwiftUI iOS app (iOS 16+) that plans one day's meal against a
profile's calorie and macro goals, tracks vitamin and mineral intake
against the NIH RDA table, prices the meal, and logs daily snapshots.

Foods, ingredient variants, prices, default meals and the RDA table are
authored in the sibling `nutrition-config` repo and pulled into the app
from GitHub (Prep tab pull-to-refresh, or the menu's "Refresh data"). The
app has no ingredient editor.

Agent rules and the build, test and install recipes are in `AGENTS.md`.
Start reading at `nutrition/NutritionApp.swift`.
