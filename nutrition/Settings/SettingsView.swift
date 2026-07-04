import SwiftUI

// ============================================================
// SettingsView — single screen for the scanner's configuration:
//   * Anthropic API key (Keychain-backed, secure entry)
//   * Default model (Sonnet vs Haiku)
//   * Test connection button (sends a tiny ping to verify the
//     key is valid before the user goes to scan)
//
// Reachable from a gear button in IngredientList's toolbar. We
// don't bother with any general "settings" tab today — this is
// the only configurable surface, and dropping it on the
// ingredients screen keeps the gear next to the camera button
// it pairs with.
// ============================================================
struct SettingsView: View {

    @Environment(\.presentationMode) private var presentationMode

    @State private var apiKey: String = ""
    @State private var model: NutritionScannerModel = .sonnet

    @State private var isTesting = false
    @State private var testResult: TestResult? = nil

    // Set when the Keychain write fails so the user isn't silently
    // left with a stale (or missing) key.
    @State private var saveError: String? = nil


    enum TestResult: Equatable {
        case success
        case failure(String)
    }


    var body: some View {
        Form {
            Section(header: Text("Anthropic API key"),
                    footer: Text("Stored in the iOS Keychain on this device.")) {
                SecureField("sk-ant-\u{2026}", text: $apiKey)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                if !apiKey.isEmpty {
                    Button(role: .destructive) {
                        apiKey = ""
                    } label: {
                        Label("Clear key", systemImage: "trash")
                    }
                }
                if let saveError {
                    Text(saveError)
                      .font(.footnote)
                      .foregroundColor(.red)
                }
            }

            Section(header: Text("Model")) {
                Picker("Default model", selection: $model) {
                    ForEach(NutritionScannerModel.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        HStack {
                            ProgressView()
                            Text("Testing\u{2026}")
                        }
                    } else {
                        Label("Test connection", systemImage: "network")
                    }
                }
                  .disabled(isTesting || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if let result = testResult {
                    switch result {
                    case .success:
                        Label("Connection OK", systemImage: "checkmark.circle.fill")
                          .foregroundColor(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.octagon.fill")
                          .foregroundColor(.red)
                    }
                }
            }
        }
          .navigationTitle("Scanner Settings")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  Button("Cancel") {
                      presentationMode.wrappedValue.dismiss()
                  }
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItem(placement: .primaryAction) {
                  Button("Save") {
                      save()
                  }
                    .foregroundColor(Color.theme.blueYellow)
              }
          }
          .onAppear {
              apiKey = KeychainStore.anthropicKey() ?? ""
              model = NutritionScannerService.selectedModel
          }
    }


    private func save() {
        guard KeychainStore.setAnthropicKey(apiKey) else {
            saveError = "Couldn't save to the Keychain — try again."
            return
        }
        saveError = nil
        NutritionScannerService.selectedModel = model
        presentationMode.wrappedValue.dismiss()
    }


    // ============================================================
    // Test connection — fires a 1-token /v1/messages call (no
    // tools, no images) just to verify the key. Cheap and quick.
    // The ping uses the in-field key directly — nothing is written
    // to the Keychain until Save.
    // ============================================================
    private func testConnection() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isTesting = true
        testResult = nil

        Task {
            let outcome = await pingAnthropic(apiKey: trimmed,
                                              model: model.rawValue)
            await MainActor.run {
                isTesting = false
                testResult = outcome
            }
        }
    }


    private func pingAnthropic(apiKey: String, model: String) async -> TestResult {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8,
            "messages": [
                ["role": "user", "content": "ping"]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .failure("Bad response")
            }
            if (200..<300).contains(http.statusCode) {
                return .success
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                return .failure("HTTP \(http.statusCode): \(body.prefix(120))")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
