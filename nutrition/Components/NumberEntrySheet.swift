import SwiftUI


// A simple sheet for entering a numeric value.  Used by the Meal
// page row pill to let the user type an exact amount without
// navigating away.
//
// Caller provides:
//   - title: shown at the top of the sheet (e.g., "Coconut Oil (tbsps)")
//   - initialValue: pre-populated in the text field
//   - onSave: invoked with the parsed Double when the user taps Save
//
// Cancel dismisses without invoking onSave.
struct NumberEntrySheet: View {

    @Environment(\.presentationMode) var presentationMode
    @FocusState private var focused: Bool

    let title: String
    let initialValue: Double
    let onSave: (Double) -> Void

    @State private var text: String


    init(title: String, initialValue: Double, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.initialValue = initialValue
        self.onSave = onSave
        _text = State(initialValue: formatNumber(initialValue))
    }


    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(title)) {
                    TextField("Amount", text: $text)
                      .keyboardType(.decimalPad)
                      .focused($focused)
                }
            }
              .navigationTitle("Set Amount")
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
                          // Values may display with grouping ("2,150"),
                          // so parse via a .decimal NumberFormatter
                          // first, falling back to Double(text).
                          let formatter = NumberFormatter()
                          formatter.numberStyle = .decimal
                          if let value = formatter.number(from: text)?.doubleValue ?? Double(text) {
                              onSave(value)
                          }
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
              .onAppear {
                  // Sheet-presentation animation can swallow a focus
                  // state set on the very first run loop. A small
                  // delay lets the animation settle so the keyboard
                  // reliably appears and the field grabs the
                  // responder.
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                      focused = true
                  }
              }
              // Pre-select all text the instant the field actually
              // becomes the first responder (numeric-entry UX: first
              // keystroke replaces the prior value instead of
              // appending). Notification-driven rather than
              // timer-driven so it fires when the UITextField is
              // genuinely ready — the previous fixed-delay
              // sendAction(selectAll:) was racing and leaving the
              // cursor at the end instead of selecting the digits.
              .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                  if let tf = note.object as? UITextField {
                      tf.selectedTextRange = tf.textRange(from: tf.beginningOfDocument, to: tf.endOfDocument)
                  }
              }
        }
    }
}


// Format a number for display: omit decimals when it's a whole
// number, keep up to two decimals otherwise.
private func formatNumber(_ value: Double) -> String {
    if value == value.rounded() {
        return String(Int(value))
    }
    return String(value)
}
