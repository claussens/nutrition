import Foundation
import Yams

// ============================================================================
// ConfigSync — GitHub-backed config refresh
// ============================================================================
//
// Pulls the five YAML files that make up the app's data set from the
// `nutrition-config` GitHub repo, parses them with Yams, validates referential
// integrity in Swift (mirroring the plugin's validate.py), and — only if
// everything succeeds — atomically applies the new data via ConfigStore.
//
// The import is ALL-OR-NOTHING: a single bad reference anywhere aborts the whole
// refresh and leaves the app's current data untouched.
//
// Change detection ("CRC"): every GitHub contents response carries a blob `sha`.
// We cache the last-applied sha per file. If all five shas match the cache, the
// refresh short-circuits to `.upToDate` and never touches ConfigStore.
//
// Dependencies: Foundation, Yams. The GitHub PAT lives in the Keychain
// (KeychainStore). The data sink (ConfigStore) is built by the orchestrator and
// is only referenced here.

// ----------------------------------------------------------------------------
// Errors
// ----------------------------------------------------------------------------

enum ConfigSyncError: LocalizedError {
    /// No GitHub PAT found in the Keychain.
    case missingToken
    /// Underlying URLSession / transport failure.
    case network(Error)
    /// GitHub returned 404 for a required file.
    case notFound(file: String)
    /// A file fetched fine but failed to parse as the expected YAML shape.
    case parse(file: String, Error)
    /// One or more referential-integrity violations (collected, all-or-nothing).
    case referenceErrors([String])
    /// A non-success HTTP status that isn't a 404 (e.g. 401 bad token, 403 rate limit).
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No GitHub access token is configured. Add a personal access token in Settings."
        case .network(let underlying):
            return "Network error while syncing config: \(underlying.localizedDescription)"
        case .notFound(let file):
            return "Config file not found in the repository: \(file)"
        case .parse(let file, let underlying):
            return "Failed to parse \(file): \(underlying.localizedDescription)"
        case .referenceErrors(let violations):
            let body = violations.map { "  • \($0)" }.joined(separator: "\n")
            return "Config validation failed (\(violations.count) issue(s)):\n\(body)"
        case .http(let code):
            return "GitHub returned HTTP \(code) while syncing config."
        }
    }
}

// ----------------------------------------------------------------------------
// ConfigSync
// ----------------------------------------------------------------------------

enum ConfigSync {

    // --- Repo coordinates (NOTE: adjust here if the repo moves) -------------
    static let owner = "claussens"
    static let repo  = "nutrition-config"

    // The five files that make up a complete config snapshot.
    static let files = (
        food: "food.yaml",
        ingredients: "ingredients.yaml",
        meals: "meals.yaml",
        supplements: "supplements.yaml",
        rda: "rda.yaml"
    )

    /// Outcome of a refresh.
    enum Result {
        /// New data was fetched, validated, and applied. `summary` is human-readable.
        case applied(summary: String)
        /// Every file's sha matched the cache; nothing was re-applied.
        case upToDate
    }

    // ------------------------------------------------------------------------
    // Public entrypoint
    // ------------------------------------------------------------------------

    /// Fetch → parse → validate → (maybe) apply. Safe to call from the main
    /// actor: all network and CPU work happens off the calling actor, and the
    /// only main-actor-affecting work (ConfigStore.apply) is awaited at the end.
    ///
    /// - Throws: `ConfigSyncError` for any failure (missing token, network,
    ///   parse, validation, HTTP).
    /// - Returns: `.applied` when data changed, `.upToDate` when it didn't.
    static func refresh() async throws -> Result {
        #if DEBUG
        // Local dev mode (`-c` / `--config-dir <dir>`) owns the config set: it's loaded
        // straight from the on-disk checkout at launch (ConfigStore.loadInitial).
        // Short-circuit EVERY refresh entry point — the launch auto-refresh and
        // the manual Refresh tap both flow through here — so GitHub never
        // overwrites the local set. Compiled out of Release.
        if LocalConfigSource.isActive { return .upToDate }
        #endif

        // 1. Credential — read the PAT from the Keychain.
        guard let token = KeychainStore.githubToken(), !token.isEmpty else {
            throw ConfigSyncError.missingToken
        }

        // 2. Fetch all five files concurrently (text + sha each).
        let fetched = try await fetchAll(token: token)

        // 3. Change detection ("CRC"): if every sha matches the cache, bail
        //    early — but only when the Documents file cache actually exists.
        //    The shas (UserDefaults) and the files (Documents) can desync,
        //    and a sha-only match would then lie "Up to date" forever.
        let newShas = fetched.mapValues { $0.sha }
        let cachedShas = ConfigStore.shared.cachedShas()
        if newShas == cachedShas && ConfigStore.shared.cacheFilesExist() {
            return .upToDate
        }

        // 4. Parse each YAML payload into its wire type. Parse errors name the file.
        let data = try parse(fetched: fetched)

        // 5. Referential-integrity validation (all violations collected).
        let violations = validate(data)
        if !violations.isEmpty {
            throw ConfigSyncError.referenceErrors(violations)
        }

        // 6. Commit: apply atomically, then persist the new shas so the next
        //    refresh can short-circuit. Order matters — only record shas once
        //    the data is safely applied. apply() mutates @Published state, so
        //    it must run on the main actor (refresh() runs on a background
        //    executor).
        try await MainActor.run {
            try ConfigStore.shared.apply(data)
            ConfigStore.shared.saveShas(newShas)
        }

        return .applied(summary: summary(for: data))
    }

    // ------------------------------------------------------------------------
    // Networking
    // ------------------------------------------------------------------------

    /// One file's fetched payload: the raw YAML text plus its GitHub blob sha.
    private struct FetchedFile {
        let text: String
        let sha: String
    }

    /// Shape of the GitHub `contents` API JSON response (non-raw form).
    private struct GitHubContentsResponse: Decodable {
        let content: String      // base64 (may contain newlines)
        let encoding: String     // expected "base64"
        let sha: String
    }

    /// Fetch all five files concurrently, keyed by filename.
    private static func fetchAll(token: String) async throws -> [String: FetchedFile] {
        let names = [files.food, files.ingredients, files.meals, files.supplements, files.rda]

        return try await withThrowingTaskGroup(of: (String, FetchedFile).self) { group in
            for name in names {
                group.addTask {
                    let file = try await fetchFile(name, token: token)
                    return (name, file)
                }
            }
            var result: [String: FetchedFile] = [:]
            for try await (name, file) in group {
                result[name] = file
            }
            return result
        }
    }

    /// Fetch a single file via the GitHub contents API. We use the *non-raw*
    /// endpoint so a single request returns both the base64 content and the sha,
    /// avoiding a second metadata round-trip.
    private static func fetchFile(_ file: String, token: String) async throws -> FetchedFile {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/contents/\(file)"
        guard let url = components.url else {
            throw ConfigSyncError.notFound(file: file)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ConfigSyncError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ConfigSyncError.http(-1)
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw ConfigSyncError.notFound(file: file)
        default:
            throw ConfigSyncError.http(http.statusCode)
        }

        let payload: GitHubContentsResponse
        do {
            payload = try JSONDecoder().decode(GitHubContentsResponse.self, from: data)
        } catch {
            throw ConfigSyncError.parse(file: file, error)
        }

        guard let text = decodeBase64(payload.content) else {
            throw ConfigSyncError.parse(file: file, DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Could not base64-decode \(file) content")))
        }
        return FetchedFile(text: text, sha: payload.sha)
    }

    /// GitHub base64-encodes blob content with embedded newlines, which the
    /// standard Data(base64Encoded:) rejects — strip whitespace first.
    private static func decodeBase64(_ encoded: String) -> String? {
        let cleaned = encoded.replacingOccurrences(of: "\n", with: "")
                             .replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // ------------------------------------------------------------------------
    // Parsing
    // ------------------------------------------------------------------------

    /// Decode each YAML payload into its wire type, assembling a ConfigData.
    /// Each decode is wrapped so a failure names the offending file.
    private static func parse(fetched: [String: FetchedFile]) throws -> ConfigData {
        let decoder = YAMLDecoder()

        func text(_ name: String) throws -> String {
            guard let file = fetched[name] else {
                throw ConfigSyncError.notFound(file: name)
            }
            return file.text
        }

        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            do {
                return try decoder.decode(T.self, from: try text(name))
            } catch let e as ConfigSyncError {
                throw e
            } catch {
                throw ConfigSyncError.parse(file: name, error)
            }
        }

        // food.yaml / ingredients.yaml are top-level arrays.
        let foods       = try decode([ConfigFood].self, files.food)
        let ingredients = try decode([ConfigIngredient].self, files.ingredients)
        // meals.yaml / supplements.yaml are top-level maps (profile slug -> rows).
        let meals       = try decode([String: [ConfigMealRow]].self, files.meals)
        let supplements = try decode([String: [ConfigSupplement]].self, files.supplements)
        // rda.yaml is a top-level map (nutrient key -> thresholds).
        let rda         = try decode([String: ConfigRDA].self, files.rda)

        return ConfigData(
            foods: foods,
            ingredients: ingredients,
            meals: meals,
            supplements: supplements,
            rda: rda
        )
    }

    // ------------------------------------------------------------------------
    // Referential-integrity validation (mirrors the plugin's validate.py)
    // ------------------------------------------------------------------------
    //
    // Collects EVERY violation (does not stop at the first) so the user sees the
    // full picture. Returns an empty array when the config is internally
    // consistent. Internal (not private): ConfigStore.loadInitial() re-runs the
    // SAME validation against the launch-time cache so a mixed/inconsistent
    // cache can't sneak past the checks a refresh would have to clear.

    static func validate(_ data: ConfigData) -> [String] {
        var errors: [String] = []

        let foodNames = Set(data.foods.map { $0.name })
        let ingredientNames = Set(data.ingredients.map { $0.name })

        // 1. Every ingredient.food must reference a known food.
        for ingredient in data.ingredients where !foodNames.contains(ingredient.food) {
            errors.append("Ingredient '\(ingredient.name)' references unknown food '\(ingredient.food)'")
        }

        // 2. Every food.currentVariant (if set) must reference a known ingredient.
        for food in data.foods {
            if let variant = food.currentVariant, !ingredientNames.contains(variant) {
                errors.append("Food '\(food.name)' current-variant references unknown ingredient '\(variant)'")
            }
        }

        // 3. Meal rows: validate `food`, `member`, and composite parts per profile.
        for (profile, rows) in data.meals {
            for (index, row) in rows.enumerated() {
                let location = "meals['\(profile)'][\(index)]"

                // Category placeholder rows ({category, food-type}) carry no food
                // reference — skip the food/member checks for those.
                let isCategoryRow = row.category != nil && row.food == nil

                if !isCategoryRow, let food = row.food, !foodNames.contains(food) {
                    errors.append("\(location) references unknown food '\(food)'")
                }

                if let member = row.member, !ingredientNames.contains(member) {
                    errors.append("\(location) member references unknown ingredient '\(member)'")
                }

                // 4. Composite parts: food ∈ foods AND variant ∈ ingredients.
                if let parts = row.composite {
                    for (partIndex, part) in parts.enumerated() {
                        let partLoc = "\(location).composite[\(partIndex)]"
                        if !foodNames.contains(part.food) {
                            errors.append("\(partLoc) references unknown food '\(part.food)'")
                        }
                        if !ingredientNames.contains(part.variant) {
                            errors.append("\(partLoc) references unknown ingredient variant '\(part.variant)'")
                        }
                    }
                }
            }
        }

        return errors
    }

    // ------------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------------

    private static func summary(for data: ConfigData) -> String {
        let mealRows = data.meals.values.reduce(0) { $0 + $1.count }
        let supplementCount = data.supplements.values.reduce(0) { $0 + $1.count }
        return "Applied: \(data.foods.count) foods, "
            + "\(data.ingredients.count) ingredients, "
            + "\(data.meals.count) meal profile(s)/\(mealRows) rows, "
            + "\(data.supplements.count) supplement profile(s)/\(supplementCount) entries, "
            + "\(data.rda.count) RDA nutrients."
    }
}
