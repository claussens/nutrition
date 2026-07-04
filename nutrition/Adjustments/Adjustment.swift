import Foundation

class AdjustmentMgr: ObservableObject {

    // The profile this manager is currently bound to. All persistence
    // is namespaced by this id via `storageKey`.
    private(set) var profileId: String

    private var storageKey: String { "adjustment.\(profileId)" }

    // Persistence codec. Built per use because storageKey re-points
    // when the profile switches. On decode failure the store backs up
    // the blob under "<key>.corrupt" and loudly logs before we reseed.
    private var store: UserDefaultsStore<[Adjustment]> {
        UserDefaultsStore(key: storageKey)
    }


    @Published var adjustments: [Adjustment] = [] {
        didSet {
            serialize()
        }
    }


    // Per-profile init. Adjustment rules are stored per profile under
    // "adjustment.<profileId>" so switching profile swaps rule sets.
    // On first load for a given profile we one-time migrate from the
    // legacy unkeyed "adjustment" UserDefaults entry (the legacy key
    // is left intact as a safety net). If no stored data exists for
    // the profile (and no legacy data to migrate), the same default
    // seeds the original init used are applied.
    init(profileId: String) {
        self.profileId = profileId
        loadForCurrentProfile()
    }


    // Re-bind this manager to a different profile and reload its
    // adjustments from per-profile storage (or seed/migrate as needed).
    func reload(forProfileId newId: String) {
        self.profileId = newId
        loadForCurrentProfile()
    }


    // Load adjustments for `profileId`. Order:
    //   1. Try the per-profile key.
    //   2. If empty and not yet migrated, try the legacy "adjustment"
    //      key, adopt it as the per-profile data, mark migrated, and
    //      persist forward under the per-profile key.
    //   3. If still empty, apply the original default seeds.
    private func loadForCurrentProfile() {
        if let savedItems = store.load() {
            self.adjustments = savedItems
            return
        }

        let migratedFlagKey = "adjustment.migrated.\(profileId)"
        let legacyConsumedKey = "adjustment.legacyConsumed"
        if !UserDefaults.standard.bool(forKey: migratedFlagKey) {
            UserDefaults.standard.set(true, forKey: migratedFlagKey)
            // Only the FIRST profile to load post-refactor consumes
            // the legacy unkeyed data; later profiles fall through to
            // the default seed below.
            if !UserDefaults.standard.bool(forKey: legacyConsumedKey),
               let legacyItems = UserDefaultsStore<[Adjustment]>(key: "adjustment").load() {
                self.adjustments = legacyItems   // didSet -> serialize() writes to storageKey
                UserDefaults.standard.set(true, forKey: legacyConsumedKey)
                return
            }
        }

        // No stored or legacy data — seed defaults (matches original init).
        // adjustments.append(Adjustment(name: "Dubliner Cheese", amount: 5, constraints: true, maximum: 100))
        // adjustments.append(Adjustment(name: "Sardines (H2O)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Sardines (SB)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Sardines (LS)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Sardines (LS L)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Mack (SB)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Mack (Smk)", amount: 1, group: "fish", constraints: true, maximum: 2))
        // adjustments.append(Adjustment(name: "Eggs", amount: 1, constraints: true, maximum: 7))

        var seeded: [Adjustment] = []
        seeded.append(Adjustment(name: "String Cheese", amount: 1, constraints: true, maximum: 8))
        // seeded.append(Adjustment(name: "Broccoli", amount: 10, group: "vegefat", constraints: true, maximum: 250))
        // seeded.append(Adjustment(name: "Cauliflower", amount: 10, group: "vegefat", constraints: true, maximum: 100))
        // seeded.append(Adjustment(name: "Extra Virgin Olive Oil", amount: 0.5, constraints: true, maximum: 2))
        seeded.append(Adjustment(name: "Pumpkin Seeds", amount: 5, group: "vegefat"))
        // seeded.append(Adjustment(name: "Macadamia Nuts", amount: 5, group: "vegefat", constraints: true, maximum: 100))
        self.adjustments = seeded
    }


    func serialize() {
        store.save(adjustments)
    }


    func create(name: String,
                amount: Double,
                group: String = "",
                active: Bool = true) {
        let adjustment = Adjustment(name: name, amount: amount, group: group, active: active)
        adjustments.append(adjustment)
    }


    func getAll(includeInactive: Bool = false) -> [Adjustment] {
        if includeInactive {
            return adjustments
        }
        return adjustments.filter({ $0.active == true })
    }


    func getByName(name: String) -> Adjustment? {
        if let index = adjustments.firstIndex(where: { $0.name == name }) {
            return adjustments[index]
        }

        return nil
    }


    func getNames() -> [String] {
        return adjustments.map { $0.name }
    }


    func update(_ adjustment: Adjustment) {
        if let index = adjustments.firstIndex(where: { $0.id == adjustment.id }) {
            adjustments[index] = adjustment
        }
    }


    func activate(_ name: String) {
        if let index = adjustments.firstIndex(where: { $0.name == name }) {
            if !adjustments[index].active {
                adjustments[index] = adjustments[index].toggleActive()
            }
        }
    }


    func deactivate(_ name: String) {
        if let index = adjustments.firstIndex(where: { $0.name == name }) {
            if adjustments[index].active {
                adjustments[index] = adjustments[index].toggleActive()
            }
        }
    }


    func inactiveIngredientsExist() -> Bool {
        let inactiveIngredients = adjustments.filter({ $0.active == false })
        return inactiveIngredients.count > 0
    }


    func toggleActive(_ adjustment: Adjustment) -> Adjustment? {
        if let index = adjustments.firstIndex(where: { $0.id == adjustment.id }) {
            adjustments[index] = adjustment.toggleActive()
            return adjustments[index]
        }
        return nil
    }


    func move(from: IndexSet, to: Int) {
        adjustments.move(fromOffsets: from, toOffset: to)
    }


    func deleteSet(indexSet: IndexSet) {
        adjustments.remove(atOffsets: indexSet)
    }


    func delete(_ adjustment: Adjustment) {
        if let index = adjustments.firstIndex(where: { $0.id == adjustment.id }) {
            adjustments.remove(at: index)
        }
    }


    // Create or update an auto-adjust rule for the named ingredient.
    // `maximum == nil` means "no cap" (constraints=false). Always
    // creates rules in the active state and without a group.
    func setAuto(name: String, amount: Double, maximum: Double?) {
        let constraints = maximum != nil
        let max = maximum ?? 0
        if let idx = adjustments.firstIndex(where: { $0.name == name }) {
            let existing = adjustments[idx]
            adjustments[idx] = Adjustment(id: existing.id, name: name, amount: amount, group: existing.group, constraints: constraints, maximum: max, active: true)
        } else {
            adjustments.append(Adjustment(name: name, amount: amount, group: "", constraints: constraints, maximum: max, active: true))
        }
    }


    // Remove the auto-adjust rule for the named ingredient. No-op
    // if none exists.
    func clearAuto(name: String) {
        if let idx = adjustments.firstIndex(where: { $0.name == name }) {
            adjustments.remove(at: idx)
        }
    }
}


struct Adjustment: Codable, Identifiable {
    var id: String
    var name: String
    var amount: Double

    var group: String

    var constraints : Bool
    var maximum: Double
    var active: Bool


    init(id: String = UUID().uuidString, name: String, amount: Double, group: String = "", constraints: Bool = false, maximum: Double = 0, active: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.group = group
        self.constraints = constraints
        self.maximum = maximum
        self.active = active
    }


    func toggleActive() -> Adjustment {
        return Adjustment(id: id, name: name, amount: amount, group: group, constraints: constraints, maximum: maximum, active: !active)
    }
}
