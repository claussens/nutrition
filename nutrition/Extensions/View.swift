import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // https://www.avanderlee.com/swiftui/conditional-view-modifier/#:~:text=Conditional%20View%20Modifier%20creation%20in,different%20configurations%20to%20your%20views.
    //
    // Applies the given transform if the given condition evaluates to `true`.
    // - Parameters:
    //   - condition: The condition to evaluate.
    //   - transform: The transform to apply to the source `View`.
    // - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    //
    // Usage example:
    //
    // struct ContentView: View {
    //
    //     private var shouldApplyBackground: Bool {
    //         guard #available(iOS 14, *) else {
    //             return true
    //         }
    //         return false
    //     }
    //
    //     var body: some View {
    //         Text("Hello, world!")
    //             .padding()
    //             .if(shouldApplyBackground) { view in
    //                 // We only apply this background color if shouldApplyBackground is true
    //                 view.background(Color.theme.red)
    //             }
    //     }
    // }
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Shared Cancel/Save toolbar for the add/edit screens (adjustments,
// meal settings): Cancel/Save in the bar, Save + keyboard-dismiss in
// the keyboard group, back button hidden. `saveDisabled` covers
// screens that gate Save.
extension View {
    func cancelSaveToolbar(saveDisabled: Bool = false,
                           onCancel: @escaping () -> Void,
                           onSave: @escaping () -> Void) -> some View {
        self
          .navigationBarBackButtonHidden(true)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  Button("Cancel", action: onCancel)
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItem(placement: .primaryAction) {
                  Button("Save", action: onSave)
                    .foregroundColor(Color.theme.blueYellow)
                    .disabled(saveDisabled)
              }
              ToolbarItemGroup(placement: .keyboard) {
                  HStack {
                      DismissKeyboard()
                      Spacer()
                      Button("Save", action: onSave)
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
          }
    }
}

struct DismissKeyboard: View {
    var body: some View {
        Button {
            self.hideKeyboard()
        } label: {
            Label("Keyboard Down", systemImage: "keyboard.chevron.compact.down")
        }
          .foregroundColor(Color.theme.blueYellow)
    }
}

struct NameViewModifier: ViewModifier {
    var geo: GeometryProxy
    var wideValue: Bool

    func body(content: Content) -> some View {
        let width = geo.size.width * (wideValue ? 0.3 : 0.6)
        return content
          .lineLimit(1)
          .font(.callout)
          .frame(minWidth: width, minHeight: 32, alignment: .leading)
    }
}

struct ValueViewModifier: ViewModifier {
    var geo: GeometryProxy
    var wideValue: Bool
    var unit: Unit

    func body(content: Content) -> some View {
        var width = geo.size.width * (wideValue ? 0.6 : 0.3)
        width += (unit == .none) ? geo.size.width * 0.1 : 0

        return content
          .lineLimit(1)
          .font(.callout)
          .multilineTextAlignment(.trailing)
          .frame(minWidth: width, minHeight: 32, alignment: .trailing)
    }
}

struct UnitViewModifier: ViewModifier {
    var geo: GeometryProxy
    var unit: Unit = .none

    func body(content: Content) -> some View {
        // The "$" reads as too small at .caption2 next to the value;
        // render it at .callout (matching the value) while every
        // other unit label stays at the compact .caption2.
        content
          .lineLimit(1)
          .font(unit == .dollar ? .callout : .caption2)
          .frame(minWidth: geo.size.width * 0.10, minHeight: 32, alignment: .leading)
          .offset(x: 4, y: 2)
    }
}

struct DescriptionViewModifier: ViewModifier {
    var geo: GeometryProxy

    func body(content: Content) -> some View {
        content
          .lineLimit(1)
          .font(.caption2)
          .frame(minWidth: geo.size.width * 1 + 5, minHeight: 10, alignment: .leading)
    }
}

extension View {
    func name(_ geo: GeometryProxy, _ wideValue: Bool) -> some View {
        return self.modifier(NameViewModifier(geo: geo, wideValue: wideValue))
    }

    func value(_ geo: GeometryProxy, _ wideValue: Bool, _ unit: Unit) -> some View {
        return self.modifier(ValueViewModifier(geo: geo, wideValue: wideValue, unit: unit))
    }

    func unit(_ geo: GeometryProxy, _ unit: Unit = .none) -> some View {
        return self.modifier(UnitViewModifier(geo: geo, unit: unit))
    }

    func description(_ geo: GeometryProxy) -> some View {
        return self.modifier(DescriptionViewModifier(geo: geo))
    }
}


struct HiddenNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
        .navigationBarTitle("", displayMode: .inline)
        // .navigationBarHidden(true)
    }
}

extension View {
    func hiddenNavigationBarStyle() -> some View {
        modifier(HiddenNavigationBar())
    }


    // Hides the system-provided List/ScrollView background on iOS 16+
    // so a custom .background color underneath shows through.  No-op on
    // iOS 15 (the modifier doesn't exist there) — falls back to UIKit
    // appearance overrides if those are also configured.  Used by
    // MealList to make the list area transparent over its grey backdrop.
    @ViewBuilder
    func hiddenScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
