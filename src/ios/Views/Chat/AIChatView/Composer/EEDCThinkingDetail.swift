import SwiftUI
import UIKit

/// Zen's curved thinking rail, bound to the levels Minis actually supports.
struct EEDCThinkingDetail: View {
    let level: ThinkingLevel
    let levels: [ThinkingLevel]
    let modelName: String
    let actions: EEDCComposerMenuActionChannel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = 0.0
    @State private var dragging = false
    @State private var endpointPulse = 0

    private var selectedIndex: Int { levels.firstIndex(of: level) ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                EEDCMenuSymbol(level: .thinking,
                               thinkingProgress: level.isEnabled && !levels.isEmpty ? Double(selectedIndex + 1) / Double(levels.count) : nil)
                    .frame(width: 25, height: 25)
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemFill), in: Circle())
                Text("Thinking").font(.headline)
                Spacer()
                Button { actions.send(.thinkingBack) } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).background(.quaternary, in: Circle())
                }.accessibilityLabel(Text("Back"))
            }.padding(.horizontal, 24).padding(.bottom, 8)
            GeometryReader { geometry in
                let compact = geometry.size.height < 250
                let thickness: CGFloat = min(compact ? 32 : 52, max(4, geometry.size.height * 0.25))
                VStack(spacing: compact ? 6 : 12) {
                    ComposerThinkingTrack(progress: position / Double(max(1, levels.count - 1)),
                        count: levels.count, thickness: thickness, isDragging: dragging,
                        endpointPulse: endpointPulse, enabled: !levels.isEmpty, interactionRevision: 0,
                        onDragStarted: { _ in dragging = true },
                        onDrag: { value in move(value) },
                        onDragEnded: { value in dragging = false; move(value); selectNearest() },
                        onDragCancelled: { dragging = false; synchronize() },
                        onSelect: { index in select(index) })
                        .frame(height: max(40, min(110, geometry.size.height * 0.38)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("Thinking Intensity"))
                        .accessibilityValue(Text(level.displayName))
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: select(min(selectedIndex + 1, levels.count - 1))
                            case .decrement: select(max(selectedIndex - 1, 0))
                            @unknown default: break
                            }
                        }
                    Text(level.displayName).font(.system(size: compact ? 22 : 28, weight: .semibold))
                        .frame(maxWidth: .infinity)
                    Text(modelName).font(.system(size: compact ? 14 : 18)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.65)
                    Button { actions.send(.setThinking(.off)) } label: {
                        Text("Off").font(.system(size: compact ? 17 : 20))
                            .foregroundStyle(level == .off ? Color.white : Color.primary)
                            .padding(.horizontal, 18).frame(height: 44)
                            .background(level == .off ? Color.black : Color(uiColor: .tertiarySystemFill), in: Capsule())
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(.primary).buttonStyle(.plain)
        .onAppear { synchronize() }
        .onChange(of: level) { _ in if !dragging { synchronize() } }
        .onChange(of: levels) { _ in synchronize() }
    }

    private func synchronize() { position = Double(selectedIndex) }
    private func move(_ fraction: Double) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { position = min(1, max(0, fraction)) * Double(max(0, levels.count - 1)) }
    }
    private func selectNearest() { select(Int(position.rounded())) }
    private func select(_ index: Int) {
        guard levels.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) { position = Double(index) }
        if level != levels[index] {
            actions.send(.setThinking(levels[index]))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if index == 0 || index == levels.count - 1 { endpointPulse &+= 1 }
    }
}
