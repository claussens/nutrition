import Foundation


// A point-in-time snapshot of a single day's meal: the per-row
// entries, the rolled-up macro/cost totals, the vitamin/mineral
// actuals, and the body params at the moment "Log Today" was
// tapped. Purely additive history — nothing here feeds back into
// the live meal/cost/macro engine.
//
// `id` is "<profileId>|<yyyy-MM-dd>" so upserts replace an
// existing same-profile same-day log instead of duplicating it,
// and two profiles logging the same day never collide.
struct DayLog: Codable, Identifiable {
    var id: String
    var profileId: String
    var date: Date
    var entries: [DayLogEntry]
    var totals: DayLogTotals
    var vitamins: [DayLogVM]
    var body: DayLogBody

    init(id: String,
         profileId: String,
         date: Date,
         entries: [DayLogEntry],
         totals: DayLogTotals,
         vitamins: [DayLogVM],
         body: DayLogBody) {
        self.id = id
        self.profileId = profileId
        self.date = date
        self.entries = entries
        self.totals = totals
        self.vitamins = vitamins
        self.body = body
    }

    // Custom decode: pre-multi-profile daylog.json files lack
    // `profileId`. Decode it as "" (meaning "pre-multi-profile
    // entry, stamped by DayLogMgr migration"); encoding stays
    // synthesized.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.profileId = try c.decodeIfPresent(String.self, forKey: .profileId) ?? ""
        self.date = try c.decode(Date.self, forKey: .date)
        self.entries = try c.decode([DayLogEntry].self, forKey: .entries)
        self.totals = try c.decode(DayLogTotals.self, forKey: .totals)
        self.vitamins = try c.decode([DayLogVM].self, forKey: .vitamins)
        self.body = try c.decode(DayLogBody.self, forKey: .body)
    }
}


// One logged meal row. `foodName` is the meal row's name (group /
// composite / ingredient name as shown in the meal list);
// `resolvedName` is the actual ingredient the macros/cost resolved
// from (the selected group member, or the same as foodName for an
// ordinary row). Macro/cost numbers are the already-computed
// actuals captured from DailySummary — not recomputed here.
struct DayLogEntry: Codable, Identifiable {
    var id: String
    var foodName: String
    var resolvedName: String
    var amount: Double
    var unit: String
    var calories: Double
    var fat: Double
    var fiber: Double
    var netCarbs: Double
    var protein: Double
    var cost: Double
}


// Day rollups — mirrors macrosMgr.macros actuals plus the meal
// cost computed exactly as DailySummary.mealTotalCost() does.
struct DayLogTotals: Codable {
    var calories: Double
    var fat: Double
    var fiber: Double
    var netCarbs: Double
    var protein: Double
    var cost: Double
}


// One vitamin/mineral actual for the day. `percentOfMin` is
// actual / min × 100 (0 when min is undefined) so the history
// view can show adequacy without re-deriving RDAs.
struct DayLogVM: Codable, Identifiable {
    var id: String { name }
    var name: String
    var amount: Double
    var unit: String
    var percentOfMin: Double
}


// Body params captured from Profile at log time. activeEnergy is
// optional and currently sourced from Profile.activeCaloriesBurned
// (a real HealthKit active-energy read is a separate TODO — see
// DayLogMgr.logToday).
struct DayLogBody: Codable {
    var weightLbs: Double?
    var age: Double?
    var activeEnergy: Double?
}
