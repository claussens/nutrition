import SwiftUI

// ============================================================
// TokenConfigSheet — sheet for entering / editing the GitHub
// Personal Access Token used by ConfigSync to pull the
// nutrition-config repo.
//
// Mirrors SettingsView's UX for the Anthropic key: a Form with
// a SecureField, a Keychain-backed credential, and Cancel/Save
// toolbar buttons tinted with Color.theme.blueYellow.
//
// We deliberately store the GitHub PAT under a distinct Keychain
// account ("github-pat") so it lives alongside — not on top of —
// the Anthropic key.
// ============================================================
struct TokenConfigSheet: View {

    @Environment(\.presentationMode) private var presentationMode

    @State private var token: String = ""

    // Snapshot of what's persisted, captured on appear. Used to show
    // a masked "currently set" hint without echoing the secret back
    // into the editable field unmasked beyond what the user types.
    @State private var savedToken: String = ""

    // Set when the Keychain write fails so the user isn't silently
    // left with a stale (or missing) token.
    @State private var saveError: String? = nil


    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GitHub token"),
                        footer: Text("A Personal Access Token with read access to the nutrition-config repo. Stored in the iOS Keychain on this device.")) {
                    SecureField("ghp_\u{2026}", text: $token)
                      .textContentType(.password)
                      .textInputAutocapitalization(.never)
                      .autocorrectionDisabled()

                    if !token.isEmpty {
                        Button(role: .destructive) {
                            token = ""
                        } label: {
                            Label("Clear token", systemImage: "trash")
                        }
                    }

                    if let saveError {
                        Text(saveError)
                          .font(.footnote)
                          .foregroundColor(Color.theme.red)
                    }
                }

                Section(header: Text("Status")) {
                    if savedToken.isEmpty {
                        Label("No token set", systemImage: "xmark.circle")
                          .foregroundColor(Color.theme.red)
                    } else {
                        Label("Token set (\(masked(savedToken)))",
                              systemImage: "checkmark.circle.fill")
                          .foregroundColor(Color.theme.green)
                    }
                }
            }
              .navigationTitle("GitHub Token")
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
                  let existing = KeychainStore.githubToken() ?? ""
                  token = existing
                  savedToken = existing
              }
        }
    }


    private func save() {
        guard KeychainStore.setGitHubToken(token) else {
            saveError = "Couldn't save to the Keychain — try again."
            return
        }
        saveError = nil
        presentationMode.wrappedValue.dismiss()
    }


    // Show only the last 4 characters so the user can confirm which
    // token is stored without exposing the full credential.
    private func masked(_ value: String) -> String {
        let suffix = value.suffix(4)
        return "\u{2022}\u{2022}\u{2022}\u{2022}\(suffix)"
    }
}
