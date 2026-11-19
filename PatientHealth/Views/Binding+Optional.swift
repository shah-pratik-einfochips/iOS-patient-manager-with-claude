import SwiftUI

extension Binding where Value == Bool {
    /// True while `optional` holds a value; setting false clears it.
    /// Drives `.alert(isPresented:)` from an optional message.
    init<Wrapped>(isPresent optional: Binding<Wrapped?>) {
        self.init(get: { optional.wrappedValue != nil }, set: { if !$0 { optional.wrappedValue = nil } })
    }
}
