import SwiftUI
import UIKit

// ============================================================
// LabelCaptureSheet — modal sheet that gathers 1+ photos, calls
// the LLM, and hands a ScanRoute back to the caller via the
// `onComplete` callback.
//
// Flow inside the sheet:
//   1. User adds photos via Camera or Library buttons.
//   2. Thumbnails appear in a horizontal row, each with a
//      small ✕ to remove.
//   3. Analyze becomes enabled when there's at least one image.
//   4. While analyzing, a spinner replaces Analyze; cancel/
//      add buttons are disabled.
//   5. On error: inline message + Retry; photos kept.
//   6. On success: dismiss + invoke onComplete with the route.
//      Caller (IngredientList) is responsible for routing to
//      IngredientAdd / IngredientEdit / MatchChooserSheet.
// ============================================================
struct LabelCaptureSheet: View {

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr

    let onComplete: (ScanRoute) -> Void

    @State private var images: [UIImage] = []
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var analyzeTask: Task<Void, Never>? = nil

    private var apiKeyConfigured: Bool {
        let key = KeychainStore.anthropicKey()
        return key != nil && !(key ?? "").isEmpty
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }


    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {

                if !apiKeyConfigured {
                    missingKeyBanner
                }

                thumbnailsRow

                addButtons

                if let msg = errorMessage {
                    errorBanner(msg)
                }

                Spacer()

                analyzeButton
            }
              .padding()
              .navigationTitle("Scan food")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .navigation) {
                      Button("Cancel") {
                          analyzeTask?.cancel()
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
              .sheet(isPresented: $showCamera) {
                  CameraPicker { image in
                      if let image = image { images.append(image) }
                  }
              }
              .sheet(isPresented: $showLibrary) {
                  PhotoLibraryPicker { picked in
                      images.append(contentsOf: picked)
                  }
              }
        }
          // An abandoned scan must not keep billing the API or
          // mutate state after dismissal — block swipe-to-dismiss
          // while analyzing and cancel the task if we do go away.
          .interactiveDismissDisabled(isAnalyzing)
          .onDisappear { analyzeTask?.cancel() }
    }


    // ============================================================
    // Subviews
    // ============================================================

    private var missingKeyBanner: some View {
        Text("Add your Anthropic API key in Settings to enable scanning.")
          .font(.callout)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.yellow.opacity(0.25))
          .cornerRadius(8)
    }


    @ViewBuilder
    private var thumbnailsRow: some View {
        if images.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                  .font(.system(size: 44))
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                Text("Photograph a nutrition label, or just snap a whole food like a banana or an avocado.")
                  .font(.callout)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                  .multilineTextAlignment(.center)
            }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 28)
              .background(Color.gray.opacity(0.08))
              .cornerRadius(8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                        thumbnail(img, index: idx)
                    }
                }
                  .padding(.horizontal, 2)
            }
        }
    }


    private func thumbnail(_ image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 100, height: 100)
              .clipped()
              .cornerRadius(8)
            Button {
                images.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.title3)
                  .foregroundColor(.white)
                  .background(Circle().fill(Color.black.opacity(0.6)))
            }
              .padding(4)
              .disabled(isAnalyzing)
        }
    }


    private var addButtons: some View {
        HStack(spacing: 10) {
            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
                  .frame(maxWidth: .infinity)
            }
              .buttonStyle(.bordered)
              .disabled(isAnalyzing || !cameraAvailable)

            Button {
                showLibrary = true
            } label: {
                Label("Library", systemImage: "photo.stack")
                  .frame(maxWidth: .infinity)
            }
              .buttonStyle(.bordered)
              .disabled(isAnalyzing)
        }
    }


    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
          .font(.callout)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.red.opacity(0.18))
          .cornerRadius(8)
    }


    @ViewBuilder
    private var analyzeButton: some View {
        if isAnalyzing {
            HStack(spacing: 10) {
                ProgressView()
                Text("Analyzing\u{2026}")
                  .font(.callout)
            }
              .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Button(action: analyze) {
                Text(errorMessage == nil ? "Analyze" : "Retry")
                  .frame(maxWidth: .infinity, minHeight: 44)
            }
              .buttonStyle(.borderedProminent)
              .tint(Color.theme.blueYellow)
              .disabled(images.isEmpty || !apiKeyConfigured)
        }
    }


    // ============================================================
    // Actions
    // ============================================================

    private func analyze() {
        errorMessage = nil
        isAnalyzing = true

        let snapshotImages = images
        let names = ingredientMgr.getAll().map { $0.name }
        let allIngredients = ingredientMgr.getAll()

        analyzeTask?.cancel()
        analyzeTask = Task {
            do {
                let parsed = try await NutritionScannerService.analyze(
                    images: snapshotImages,
                    existingNames: names
                )
                let route = ScanReviewRouter.route(
                    parsed: parsed,
                    allIngredients: allIngredients
                )
                await MainActor.run {
                    isAnalyzing = false
                    presentationMode.wrappedValue.dismiss()
                    // Slight delay so the sheet animates out before
                    // the next screen pushes — feels cleaner than
                    // a hard cut.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onComplete(route)
                    }
                }
            } catch {
                // A cancelled scan (Cancel button, sheet dismissed) is
                // not an error — reset the spinner and stay quiet.
                if error is CancellationError || Task.isCancelled {
                    await MainActor.run { isAnalyzing = false }
                    return
                }
                await MainActor.run {
                    isAnalyzing = false
                    if let scannerErr = error as? NutritionScannerError {
                        errorMessage = scannerErr.errorDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
