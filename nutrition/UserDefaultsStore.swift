import Foundation

// ============================================================
// UserDefaultsStore — the one JSON-in-UserDefaults codec for the
// user-owned managers (meals, adjustments, profiles, composites).
// Replaces five hand-rolled serialize/load pairs that all did
// `try? decode … else reseed`, where a single bad blob (e.g. a
// Codable schema change) silently threw the user's data away.
//
// Policy on decode failure: do NOT silently reseed. The raw blob
// is first backed up under "<key>.corrupt" (so the data remains
// recoverable), a loud diagnostic is logged, and only then does
// load() return nil so the caller can fall back to its seed.
//
// Keys are passed per call because the per-profile managers
// namespace them at runtime ("mealIngredient.<profileId>", …).
// ============================================================
struct UserDefaultsStore<T: Codable> {

    let key: String

    /// Decode the stored value. nil when nothing is stored, or when
    /// decoding fails — in which case the raw blob has been backed up
    /// under "<key>.corrupt" and the failure logged.
    func load() -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            UserDefaults.standard.set(data, forKey: "\(key).corrupt")
            print("""
                UserDefaultsStore: FAILED to decode '\(key)' as \(T.self): \(error)
                UserDefaultsStore: raw blob backed up under '\(key).corrupt'; caller will fall back to its seed.
                """)
            return nil
        }
    }

    /// Encode + persist. An encode failure is logged (it should be
    /// impossible for these value types) and leaves the stored value
    /// untouched rather than clearing it.
    func save(_ value: T) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("UserDefaultsStore: FAILED to encode '\(key)' as \(T.self): \(error)")
        }
    }
}
