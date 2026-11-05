import SwiftUI

enum ThinkingLevel: Equatable { case off, low, high
    var isEnabled: Bool { self != .off }
    var displayName: String { String(describing: self) }
}
enum EEDCMenuLevel { case thinking }
struct EEDCMenuSymbol: View {
    let level: EEDCMenuLevel
    var thinkingProgress: Double?
    var body: some View { EmptyView() }
}
@MainActor final class EEDCComposerMenuActionChannel {
    enum Action { case thinkingBack, setThinking(ThinkingLevel) }
    func send(_ action: Action) {}
}
