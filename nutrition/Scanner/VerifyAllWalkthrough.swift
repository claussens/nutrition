import SwiftUI


// Sequential "verify every ingredient" sweep. For each ingredient
// in turn it web-searches the canonical product (pinned to the
// agreed brand once one is set), then shows a review step:
//
//   • Brand — always editable and always confirmed, even when
//     unchanged, so future verifies can look up the exact product.
//   • Proposed macro / vitamin / price changes — per-row toggles,
//     confident ones pre-checked, price unchecked by default.
//
// Verification runs on demand for the current ingredient only —
// stopping early never spends web searches on ingredients you
// didn't reach.
struct VerifyAllWalkthrough: View {

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr

    // Name snapshot taken once so the list is stable even as we
    // write updates back. Each step re-fetches the live Ingredient
    // by name.
    @State private var names: [String] = []
    @State private var index = 0

    enum Phase { case searching, review, error(String), done }
    @State private var phase: Phase = .searching

    @State private var parsed: ParsedIngredient? = nil
    @State private var changes: [ScanDiff.Change] = []
    @State private var selected: Set<String> = []
    @State private var brandText: String = ""
    @State private var verifyTask: Task<Void, Never>? = nil


    private var currentName: String? {
        index < names.count ? names[index] : nil
    }


    var body: some View {
        Group {
            switch phase {
            case .searching: searchingView
            case .review:    reviewView
            case .error(let m): errorView(m)
            case .done:      doneView
            }
        }
          .navigationTitle("Verify All")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  Button("Stop") {
                      verifyTask?.cancel()
                      presentationMode.wrappedValue.dismiss()
                  }
                    .foregroundColor(Color.theme.blueYellow)
              }
          }
          .onAppear {
              if names.isEmpty {
                  names = ingredientMgr.getAll().map { $0.name }
                  startCurrent()
              }
          }
          // Stopping early must not keep billing the API or mutate
          // state after the walkthrough goes away.
          .onDisappear { verifyTask?.cancel() }
    }


    // ============================================================
    // Phase views
    // ============================================================

    private var progressText: String {
        "\(min(index + 1, names.count)) / \(names.count)"
    }


    private var searchingView: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(currentName ?? "")
              .font(.headline)
            Text("Looking up the product\u{2026}  (\(progressText))")
              .font(.caption)
              .foregroundColor(Color.theme.blackWhiteSecondary)
        }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var reviewView: some View {
        Form {
            SessionScopedEditsNote()
            Section {
                HStack {
                    Text(currentName ?? "").font(.headline)
                    Spacer()
                    Text(progressText)
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                }
            }

            Section(header: Text("Brand"),
                    footer: Text("Confirm the brand so future verifies look up this exact product. Saved on Apply.")
                      .font(.caption2)) {
                TextField("brand", text: $brandText)
                  .autocorrectionDisabled()
            }

            if changes.isEmpty {
                Section {
                    Text("No nutrition or price changes proposed.")
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                }
            } else {
                Section(header: Text("Proposed changes")) {
                    ForEach(changes) { c in
                        Button {
                            if selected.contains(c.id) { selected.remove(c.id) }
                            else { selected.insert(c.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(c.id)
                                        ? "checkmark.circle.fill" : "circle")
                                  .foregroundColor(Color.theme.blueYellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.field)
                                      .font(.callout)
                                      .foregroundColor(Color.theme.blackWhite)
                                    Text("\(c.oldValue) \u{2192} \(c.newValue)")
                                      .font(.caption)
                                      .foregroundColor(Color.theme.blackWhiteSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    applyAndNext()
                } label: {
                    Label("Apply & Next", systemImage: "checkmark.circle")
                      .foregroundColor(Color.theme.blueYellow)
                }
                Button {
                    advance()
                } label: {
                    Label("Skip", systemImage: "arrow.right.circle")
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                }
            }
        }
    }


    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.orange)
            Text(currentName ?? "").font(.headline)
            Text(message)
              .font(.caption)
              .multilineTextAlignment(.center)
              .foregroundColor(Color.theme.red)
              .padding(.horizontal)
            HStack(spacing: 24) {
                Button("Retry") { startCurrent() }
                  .foregroundColor(Color.theme.blueYellow)
                Button("Skip") { advance() }
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }
        }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
              .font(.largeTitle)
              .foregroundColor(Color.theme.green)
            Text("Reviewed all \(names.count) ingredients.")
              .font(.headline)
            Button("Done") { presentationMode.wrappedValue.dismiss() }
              .foregroundColor(Color.theme.blueYellow)
        }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    // ============================================================
    // Flow
    // ============================================================

    private func startCurrent() {
        guard let name = currentName,
              let ing = ingredientMgr.getByName(name: name) else {
            phase = .done
            return
        }
        phase = .searching
        verifyTask?.cancel()
        // Capture the position this lookup was started for, so a
        // stale response can never mutate the next item's review
        // state after the user has already moved on.
        let expectedIndex = index
        verifyTask = Task {
            do {
                let p = try await NutritionScannerService.verifyByName(ing)
                let d = ScanDiff.compute(existing: ing, parsed: p)
                // Brand is confirmed via its own field, so drop it
                // from the toggle list to avoid double-handling.
                let rows = d.changes.filter { $0.id != "brand" }
                await MainActor.run {
                    guard index == expectedIndex else { return }
                    parsed = p
                    changes = rows
                    // Leave price and low-confidence fields unchecked so
                    // they require an explicit opt-in, matching the
                    // single-ingredient verify flow in IngredientEdit.
                    selected = Set(rows.map { $0.id })
                      .subtracting(["price"])
                      .subtracting(Set(p.lowConfidenceFields))
                    let proposedBrand = (p.brand ?? "").trimmingCharacters(in: .whitespaces)
                    brandText = proposedBrand.isEmpty ? ing.brand : proposedBrand
                    phase = .review
                }
            } catch {
                // A cancelled lookup (Stop button, view dismissed) is
                // not an error — return without switching to .error.
                if error is CancellationError || Task.isCancelled {
                    return
                }
                await MainActor.run {
                    guard index == expectedIndex else { return }
                    phase = .error((error as? NutritionScannerError)?.errorDescription
                                     ?? error.localizedDescription)
                }
            }
        }
    }


    private func applyAndNext() {
        if let name = currentName,
           var ing = ingredientMgr.getByName(name: name),
           let p = parsed {
            ScanDiff.apply(parsed: p, ids: selected, to: &ing)
            let agreedBrand = brandText.trimmingCharacters(in: .whitespaces)
            if !agreedBrand.isEmpty {
                ing.brand = agreedBrand
            }
            ing.verified = ScanDiff.todayStamp()
            ingredientMgr.update(ing)
        }
        advance()
    }


    private func advance() {
        index += 1
        if index >= names.count {
            phase = .done
        } else {
            startCurrent()
        }
    }
}
