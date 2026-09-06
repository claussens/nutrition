import SwiftUI

// ============================================================
// HamburgerMenu — a reusable toolbar entry point (a
// `line.3.horizontal` button) that opens a menu of app-level
// actions. Drop `HamburgerMenu()` into any toolbar.
//
// Today it carries:
//   * Configure GitHub token\u{2026}  — presents TokenConfigSheet
//   * Refresh data               — runs ConfigSync.refreshWithFeedback()
//                                  (the Prep tab's pull-to-refresh runs
//                                  the same call, so the alerts match)
//
// It's structured as a Menu with Sections so callers can add
// items to a new section — no plumbing changes required. All
// presentation state (sheet, refreshing flag, result alert) is
// kept self-contained here.
// ============================================================
struct HamburgerMenu<Extra: View>: View {

    // Caller-supplied menu items (the header's relocated actions —
    // Reset / Vitamins & minerals / Cost / Settings). Rendered as the
    // first section so they read as the primary menu content.
    @ViewBuilder private let extra: Extra

    init(@ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.extra = extra()
    }

    @State private var showTokenSheet = false
    @State private var isRefreshing = false
    @State private var feedback: ConfigSync.Feedback? = nil

    // A GitHub token must be configured before Refresh can run. Read
    // live each time the menu opens (body re-evaluates), and again
    // after the token sheet dismisses.
    private var hasToken: Bool { !(KeychainStore.githubToken() ?? "").isEmpty }


    var body: some View {
        Menu {
            Section { extra }

            Section {
                Button {
                    showTokenSheet = true
                } label: {
                    Label("Configure GitHub token\u{2026}", systemImage: "key")
                }

                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        Label("Refreshing\u{2026}", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Refresh data", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                  // Greyed out until a GitHub token is configured.
                  .disabled(isRefreshing || !hasToken)
            }
        } label: {
            Image(systemName: "line.3.horizontal")
              .foregroundColor(Color.theme.blueYellow)
        }
          .sheet(isPresented: $showTokenSheet) {
              TokenConfigSheet()
          }
          .alert(item: $feedback) { f in
              Alert(title: Text(f.title),
                    message: Text(f.message),
                    dismissButton: .default(Text("OK")))
          }
    }


    // Refresh — runs ConfigSync off the main actor, flips the
    // in-progress flag, and shows the shared Feedback as an alert.
    // (The item is disabled without a token, so needsToken never
    // fires from here.)
    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let result = await ConfigSync.refreshWithFeedback()
            await MainActor.run {
                isRefreshing = false
                feedback = result
            }
        }
    }
}
