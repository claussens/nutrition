import Foundation
import UIKit

// ============================================================
// NutritionScannerService — single-purpose Anthropic Vision
// client. Takes one or more nutrition-label images plus the
// names of ingredients we already track, returns a fully
// decoded ParsedIngredient.
//
// The whole HTTP shape (model, headers, tool definition,
// content blocks) lives here so the rest of the app deals
// only in `ParsedIngredient`. SwiftUI views never import
// URLSession.
//
// We use Anthropic's tool-use with `tool_choice` forcing
// `submit_ingredient`. That guarantees Claude returns a
// `tool_use` content block whose `input` field is JSON we
// can decode straight into our struct — no markdown fences,
// no regex, no "did the model wrap it in prose?"
// ============================================================
enum NutritionScannerError: LocalizedError {
    case missingApiKey
    case invalidResponse
    case server(status: Int, body: String)
    case noToolUseInResponse
    case truncated
    case decoding(Error)
    case encoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Add your Anthropic API key in Settings."
        case .invalidResponse:
            return "Anthropic returned an unexpected response."
        case .server(let status, let body):
            return "Anthropic error \(status): \(body)"
        case .noToolUseInResponse:
            return "Model didn't return a structured result. Try again or with a clearer photo."
        case .truncated:
            return "The model's reply was cut off before it finished (max_tokens). Try again, or with fewer photos."
        case .decoding(let err):
            return "Couldn't decode the model's reply: \(err.localizedDescription)"
        case .encoding(let err):
            return "Couldn't build the request: \(err.localizedDescription)"
        case .transport(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}


enum NutritionScannerModel: String, CaseIterable, Identifiable {
    case sonnet = "claude-sonnet-4-6"
    case haiku  = "claude-haiku-4-5"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sonnet: return "Sonnet 4.6 (best)"
        case .haiku:  return "Haiku 4.5 (fast)"
        }
    }
}


struct NutritionScannerService {

    // The selected model is read from UserDefaults each call so
    // changes in Settings take effect immediately without a service
    // restart.
    static let modelDefaultsKey = "nutritionScannerModel"

    static var selectedModel: NutritionScannerModel {
        get {
            let raw = UserDefaults.standard.string(forKey: modelDefaultsKey) ?? ""
            return NutritionScannerModel(rawValue: raw) ?? .sonnet
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modelDefaultsKey)
        }
    }


    // ============================================================
    // Public entry point.
    // ============================================================
    static func analyze(images: [UIImage],
                        existingNames: [String]) async throws -> ParsedIngredient {
        guard let apiKey = KeychainStore.anthropicKey(), !apiKey.isEmpty else {
            throw NutritionScannerError.missingApiKey
        }

        let payload = try buildRequestBody(images: images, existingNames: existingNames)
        let request = try buildURLRequest(apiKey: apiKey, body: payload)

        let data = try await send(request)
        return try decodeToolUse(from: data)
    }


    // ============================================================
    // Verify-by-name: no photo. Given an ingredient we already have,
    // ask Claude to web-search the canonical product (prefer Whole
    // Foods 365, else the common brand), determine brand, find a
    // current approximate price + package size, and re-verify macros
    // and vitamins/minerals against the stored values. Price is
    // always returned low-confidence (web prices are region/time
    // approximate) so the caller never auto-applies it.
    // ============================================================
    static func verifyByName(_ ingredient: Ingredient) async throws -> ParsedIngredient {
        guard let apiKey = KeychainStore.anthropicKey(), !apiKey.isEmpty else {
            throw NutritionScannerError.missingApiKey
        }

        let payload = buildVerifyBody(ingredient: ingredient)
        let request = try buildURLRequest(apiKey: apiKey, body: payload)

        let data = try await send(request)
        return try decodeToolUse(from: data)
    }


    // ============================================================
    // Shared request sender with retry. Transient failures —
    // flaky network, 429 rate limiting, 5xx server errors — get
    // up to 3 attempts with a short backoff (~1s, then ~2s).
    // Task.sleep is used for the backoff so cancellation
    // propagates instead of stalling. Anything non-transient
    // (other 4xx, a non-HTTP response) throws immediately with
    // the same error mapping the callers always used, and the
    // final failed attempt keeps the same status→error semantics.
    // ============================================================
    private static func send(_ request: URLRequest) async throws -> Data {
        let retryableURLCodes: Set<URLError.Code> = [
            .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed
        ]
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            let isLastAttempt = attempt == maxAttempts

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch let err as URLError where retryableURLCodes.contains(err.code) && !isLastAttempt {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                continue
            } catch {
                throw NutritionScannerError.transport(error)
            }

            guard let http = response as? HTTPURLResponse else {
                throw NutritionScannerError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let retryable = http.statusCode == 429
                  || (500...599).contains(http.statusCode)
                if retryable && !isLastAttempt {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                    continue
                }
                let body = String(data: data, encoding: .utf8) ?? ""
                throw NutritionScannerError.server(status: http.statusCode, body: body)
            }
            return data
        }
        // Unreachable — every loop path either returns or throws.
        throw NutritionScannerError.invalidResponse
    }


    private static func buildVerifyBody(ingredient i: Ingredient) -> [String: Any] {
        // Compact snapshot of the stored values so the model can
        // compare and only flag genuine differences.
        func n(_ v: Double) -> String {
            // String(format:) rather than String(Int(v)) — Int() traps
            // on huge or non-finite doubles from config data.
            v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
        }
        // One "id: value" pair per scannable nutrient, 5 per line —
        // driven by the catalog so verify re-checks every nutrient the
        // scanner can return (previously the extended macros were
        // omitted from the snapshot).
        let scannable = NutrientCatalog.scannable
        let nutrientLines = stride(from: 0, to: scannable.count, by: 5).map { start in
            scannable[start..<Swift.min(start + 5, scannable.count)]
                .map { "\($0.id): \(n(i[keyPath: $0.ingredient]))" }
                .joined(separator: "  ")
        }.joined(separator: "\n")

        let stored = """
        name: \(i.name)
        brand: \(i.brand.isEmpty ? "(none)" : i.brand)
        storedPrice(totalCost): \(n(i.totalCost))
        storedPackageGrams(totalGrams): \(n(i.totalGrams))
        servingSize(g): \(n(i.servingSize))
        consumptionUnit: \(i.consumptionUnit.singularForm)
        consumptionGrams: \(n(i.consumptionGrams))
        \(nutrientLines)
        """

        // When the user has already agreed on a brand, that brand is
        // authoritative — pin the lookup to that exact product so
        // repeat verifies stay consistent. Otherwise fall back to the
        // Whole Foods 365 / common-brand heuristic.
        let brandDirective: String
        if i.brand.isEmpty {
            brandDirective = """
            Use web search to find the canonical retail product for it \
            — PREFER the Whole Foods 365 / Whole Foods Market store \
            brand; if Whole Foods doesn't carry it, use the most common \
            widely-available brand.
            """
        } else {
            brandDirective = """
            This ingredient's brand has already been confirmed as \
            "\(i.brand)". Treat that brand as authoritative — web-search \
            that EXACT product (\(i.brand) \(i.name)) and do not switch \
            to a different brand. Keep `brand` = "\(i.brand)" unless the \
            product clearly no longer exists under that brand.
            """
        }

        let instruction = """
        We already track this food ingredient. \(brandDirective) Then:

        1. Confirm/return the brand in `brand`.
        2. Find a CURRENT approximate retail price (USD) for one \
        package and that package's size in grams. Put them in `price` \
        and `packageGrams`. Web prices vary by region and over time, \
        so ALWAYS include "price" (and "packageGrams" if estimated) in \
        lowConfidenceFields.
        3. Re-verify the macros and vitamins/minerals against the \
        stored values below. The stored values use a serving size of \
        \(n(i.servingSize)) g — return your nutrition values on the \
        SAME serving-size basis so they're directly comparable. Only \
        change a field if you're confident the stored value is wrong; \
        otherwise return the stored value unchanged. List any nutrition \
        field you are NOT confident about in lowConfidenceFields.

        Set match.kind = "update" and match.name = "\(i.name)". Call \
        the `submit_ingredient` tool exactly once with the final values.

        Stored values:
        \(stored)
        """

        let webSearch: [String: Any] = [
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5
        ]

        return [
            "model": selectedModel.rawValue,
            "max_tokens": 4096,
            "tools": [webSearch, toolDefinition()],
            // auto (not forced) so the model can search first, then
            // call submit_ingredient on its final turn.
            "tool_choice": ["type": "auto"],
            "messages": [
                ["role": "user", "content": instruction]
            ]
        ]
    }


    // ============================================================
    // Request construction
    // ============================================================

    // Anthropic /v1/messages request body. Each image is JPEG-
    // encoded and base64'd; existing-ingredient context is text.
    private static func buildRequestBody(images: [UIImage],
                                         existingNames: [String]) throws -> [String: Any] {

        // Build the user message content blocks: one image block
        // per photo, then a text block with instructions and the
        // existing-ingredient context.
        var content: [[String: Any]] = []

        for image in images {
            guard let data = downscaleAndJPEG(image, maxLongEdge: 1568, quality: 0.85) else {
                continue
            }
            let base64 = data.base64EncodedString()
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        // If every image failed JPEG conversion we'd otherwise send a
        // request with no images at all; fail clearly instead.
        guard !content.isEmpty else {
            throw NutritionScannerError.invalidResponse
        }

        let namesText: String
        if existingNames.isEmpty {
            namesText = "(none)"
        } else {
            // Newline-separated keeps it cheap and easy to read.
            namesText = existingNames.sorted().joined(separator: "\n")
        }

        let instruction = """
        You are looking at one or more photos of a single food. There are two \
        kinds of input — figure out which one you're looking at:

        A) PACKAGED PRODUCT WITH A NUTRITION LABEL. One or more photos of the \
        same product (e.g. front of package + nutrition facts label). Read the \
        values directly off the label. Do not invent values that aren't printed \
        on the label — leave unseen fields null.

        B) WHOLE / RAW / UNPACKAGED FOOD with no nutrition label (e.g. a banana, \
        a tangerine, an avocado, a raw chicken breast, a bowl of rice). There is \
        no label to read, so IDENTIFY the food and fill in TYPICAL nutrition \
        values from well-established general nutrition knowledge (USDA-style \
        reference data). In this case EVERY nutrition field you populate is an \
        estimate, so you MUST list every populated nutrition field name in \
        lowConfidenceFields so the user knows to verify them.

        Existing ingredients we already track (case-insensitive):
        \(namesText)

        Decide whether this scan is:
          - "new"       : a food/product we don't already have
          - "update"    : the same food/product as one in the list above (set match.name)
          - "ambiguous" : could plausibly be one of several existing ones \
        (set match.candidates with the names from the list)

        Then call the `submit_ingredient` tool exactly once with the parsed values.

        Field guidelines:
          - name: for a whole food use its common name ("Banana", "Tangerine").
          - Use grams unless the label only shows other units; convert mg→g for \
        macronutrients but keep mg for sodium and most minerals (the schema \
        comments tell you which units to use per field).
          - Vitamins D/A typically in mcg, Calcium/Iron/Potassium/Phosphorus/\
        Magnesium/Sodium in mg, Selenium/Folate/Vitamin K in mcg, Vitamin C/E \
        in mg, B-vitamins in mg or mcg as labeled.
          - Case A (label): if a field is not visible on the label, leave it \
        null. Do not guess. List any value you're unsure about in lowConfidenceFields.
          - Case B (whole food): provide your best typical values for the common \
        macros and the vitamins/minerals the food is notable for; leave truly \
        unknown trace nutrients null; put EVERY value you did populate in \
        lowConfidenceFields (they are all estimates).
          - servingSize is in grams. For a countable whole food (banana, egg, \
        tangerine, avocado) set consumptionUnit to the natural unit ("piece" or \
        "whole"), and set servingSize AND consumptionGrams to the typical gram \
        weight of ONE (e.g. one medium banana ≈ 118 g, one tangerine ≈ 88 g, \
        one large egg ≈ 50 g). For a bulk food (rice, spinach, ground beef) use \
        a 100 g serving with consumptionUnit "gram". If a label uses a household \
        measure (1 tbsp, 1 cup, 1 piece), set consumptionUnit to that and \
        consumptionGrams to the gram weight per unit.
        """

        content.append([
            "type": "text",
            "text": instruction
        ])

        let body: [String: Any] = [
            "model": selectedModel.rawValue,
            "max_tokens": 2048,
            "tools": [toolDefinition()],
            "tool_choice": ["type": "tool", "name": "submit_ingredient"],
            "messages": [
                ["role": "user", "content": content]
            ]
        ]
        return body
    }


    private static func buildURLRequest(apiKey: String,
                                        body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        // Verify can run up to 5 server-side web searches (non-streaming), so 60s is too short.
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // A serialization failure here would otherwise yield a nil body
        // and a confusing server 400; surface it as a clear error.
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw NutritionScannerError.encoding(error)
        }
        return req
    }


    // ============================================================
    // Response parsing — Anthropic wraps the tool input in a
    // `content` array; we walk it looking for the tool_use block
    // for our submit_ingredient tool, then re-encode that input
    // dict and JSONDecoder it into ParsedIngredient.
    // ============================================================
    private static func decodeToolUse(from data: Data) throws -> ParsedIngredient {
        let root: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NutritionScannerError.invalidResponse
            }
            root = parsed
        } catch let err as NutritionScannerError {
            throw err
        } catch {
            // Preserve the underlying JSON error so a malformed top-level
            // response is diagnosable rather than an opaque "invalid".
            throw NutritionScannerError.decoding(error)
        }
        // A max_tokens truncation can carry a mangled or absent
        // tool_use block — without this check that surfaces as a
        // misleading "didn't return a structured result".
        if (root["stop_reason"] as? String) == "max_tokens" {
            throw NutritionScannerError.truncated
        }
        guard let blocks = root["content"] as? [[String: Any]] else {
            throw NutritionScannerError.invalidResponse
        }

        for block in blocks {
            if (block["type"] as? String) == "tool_use",
               (block["name"] as? String) == "submit_ingredient",
               let input = block["input"] as? [String: Any] {
                do {
                    let inputData = try JSONSerialization.data(withJSONObject: input)
                    return try JSONDecoder().decode(ParsedIngredient.self, from: inputData)
                } catch {
                    throw NutritionScannerError.decoding(error)
                }
            }
        }
        throw NutritionScannerError.noToolUseInResponse
    }


    // ============================================================
    // Image preprocessing — Anthropic accepts up to 5MB per image
    // but recommends ~1568px on the long edge for vision tasks.
    // We also re-encode as JPEG to drop alpha and shrink size.
    // ============================================================
    private static func downscaleAndJPEG(_ image: UIImage,
                                         maxLongEdge: CGFloat,
                                         quality: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxLongEdge ? maxLongEdge / longest : 1.0
        let newSize = CGSize(width: floor(size.width * scale),
                             height: floor(size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }


    // ============================================================
    // Tool schema — kept inline so the schema and the Codable
    // struct evolve together. Field types match ParsedIngredient
    // exactly. Anthropic's JSON-schema dialect supports
    // `["number","null"]` arrays for nullable fields.
    // ============================================================
    private static func toolDefinition() -> [String: Any] {
        let nullableNumber: [String: Any] = ["type": ["number", "null"]]
        let nullableString: [String: Any] = ["type": ["string", "null"]]
        let nullableStringArray: [String: Any] = [
            "type": ["array", "null"],
            "items": ["type": "string"]
        ]

        var props: [String: Any] = [
            "match": [
                "type": "object",
                "required": ["kind"],
                "properties": [
                    "kind": ["type": "string", "enum": ["new", "update", "ambiguous"]],
                    "name": ["type": "string",
                             "description": "When kind=update: the existing ingredient name being updated."],
                    "candidates": ["type": "array", "items": ["type": "string"],
                                   "description": "When kind=ambiguous: 2+ existing names that might match."]
                ]
            ],
            "name": ["type": "string"],
            "brand": nullableString,
            "fullName": nullableString,
            "url": nullableString,
            "ingredientsList": nullableStringArray,
            "allergens": nullableStringArray,
            "servingSize": nullableNumber,
            "consumptionUnit": [
                "type": ["string", "null"],
                "enum": ["gram", "tablespoon", "cup", "piece", "egg",
                         "slice", "can", "bar", "whole", "pill", NSNull()]
            ],
            "consumptionGrams": nullableNumber,
            "price": [
                "type": ["number", "null"],
                "description": "Current approximate retail price in USD for one package/unit of this product. Always also list \"price\" in lowConfidenceFields — web prices are region- and time-approximate."
            ],
            "packageGrams": [
                "type": ["number", "null"],
                "description": "Total grams of the ingredient in the priced package (so price ÷ packageGrams = cost per gram)."
            ],
            "lowConfidenceFields": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Names of fields the model is unsure about."
            ]
        ]

        // Macros + V&M — every scannable nutrient in the catalog, so
        // the schema and ParsedIngredient can't drift.
        for d in NutrientCatalog.scannable {
            props[d.id] = nullableNumber
        }

        return [
            "name": "submit_ingredient",
            "description": "Submit one parsed ingredient extracted from one or more nutrition label photos.",
            "input_schema": [
                "type": "object",
                "required": ["match", "name", "lowConfidenceFields"],
                "properties": props
            ]
        ]
    }
}
