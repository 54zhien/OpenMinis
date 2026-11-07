//
//  ContentView+Layout.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  ContentView, layout: `splitLayout` (NavigationSplitView for iPad / wide
//  windows), `stackLayout` (NavigationStack for iPhone / narrow windows) and
//  the split view's `detailView`. `body` picks one by width.
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI
import UIKit

private let shareLog = AppLogger(category: "Share")
private let draftLog = AppLogger(category: "DraftSession")

enum EEDCSidebar { case closed, history, actions }

enum EEDCSidebarGeometry {
    static let actionWidth: CGFloat = 96

    static func historyWidth(for width: CGFloat) -> CGFloat {
        max(1, min(width * 0.78, 340))
    }

    static func scale(for progress: CGFloat) -> CGFloat {
        1 - 0.02 * min(1, max(0, progress))
    }

    static func clampedOffset(_ value: CGFloat, start: Int, historyWidth: CGFloat, actionWidth: CGFloat) -> CGFloat {
        min(start == -1 ? 0 : historyWidth, max(start == 1 ? 0 : -actionWidth, value))
    }

    static func destination(projected: CGFloat, start: Int, historyWidth: CGFloat, actionWidth: CGFloat) -> Int {
        if start == 1 { return projected > historyWidth * 0.45 ? 1 : 0 }
        if start == -1 { return projected < -actionWidth * 0.45 ? -1 : 0 }
        if projected > historyWidth * 0.45 { return 1 }
        if projected < -actionWidth * 0.45 { return -1 }
        return 0
    }

    static func revealProgress(offset: CGFloat, historyWidth: CGFloat, actionWidth: CGFloat) -> CGFloat {
        let railWidth = offset >= 0 ? historyWidth : actionWidth
        return min(1, abs(offset) / max(1, railWidth))
    }

    static func cardHeight(geometryHeight: CGFloat, topGap: CGFloat, bottomGap: CGFloat) -> CGFloat {
        max(0, geometryHeight) + max(0, topGap) + max(0, bottomGap)
    }

    static func cardVerticalOffset(topGap: CGFloat, bottomGap: CGFloat) -> CGFloat {
        (max(0, bottomGap) - max(0, topGap)) / 2
    }

    static func surfaceComponent(base: CGFloat, progress: CGFloat, dark: Bool) -> CGFloat {
        let component = min(1, max(0, base))
        let fraction = min(1, max(0, progress))
        if dark { return component * (1 - 0.08 * fraction) }

        // A slightly off-white resting card gives the light reveal room to brighten.
        let resting = component * 0.98
        return resting + (component - resting) * fraction
    }

    static func cardOffset(_ offset: CGFloat, width: CGFloat, progress: CGFloat) -> CGFloat {
        offset - width * (1 - scale(for: progress)) / 2
    }

    static func settingsBottom(radius: CGFloat, bottomInset: CGFloat) -> CGFloat {
        radius >= 36 ? radius - 28 - bottomInset : 16
    }

    static func settingsShift(radius: CGFloat) -> CGFloat {
        radius >= 36 ? 48 - radius : 0
    }

    static func railTop(radius: CGFloat, safeTop: CGFloat, originTop: CGFloat) -> CGFloat {
        max(0, max(radius - 28, safeTop + 12) - originTop)
    }
}

private struct EEDCWindowCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 36
}

extension EnvironmentValues {
    var eedcWindowCornerRadius: CGFloat {
        get { self[EEDCWindowCornerRadiusKey.self] }
        set { self[EEDCWindowCornerRadiusKey.self] = newValue }
    }
}

final class EEDCSidebarSurfaceState: ObservableObject {
    @Published private(set) var progress: CGFloat = 0

    func update(progress value: CGFloat) {
        let next = min(1, max(0, value))
        guard abs(progress - next) > 0.001 else { return }
        progress = next
    }
}

private struct EEDCSidebarSurfaceStateKey: EnvironmentKey {
    static let defaultValue: EEDCSidebarSurfaceState? = nil
}

extension EnvironmentValues {
    var eedcSidebarSurfaceState: EEDCSidebarSurfaceState? {
        get { self[EEDCSidebarSurfaceStateKey.self] }
        set { self[EEDCSidebarSurfaceStateKey.self] = newValue }
    }
}

struct EEDCCardSurfaceBackground: View {
    @Environment(\.eedcSidebarSurfaceState) private var surfaceState

    var body: some View {
        if let surfaceState {
            EEDCCardSurfaceColor(surfaceState: surfaceState)
        } else {
            ChatColors.background
        }
    }
}

private struct EEDCCardSurfaceColor: View {
    @ObservedObject var surfaceState: EEDCSidebarSurfaceState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color(uiColor: resolvedSurface)
    }

    private var resolvedSurface: UIColor {
        let dark = colorScheme == .dark
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let base = ChatColors.backgroundUIColor(for: traits).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        guard base.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return base }
        return UIColor(
            red: EEDCSidebarGeometry.surfaceComponent(base: red, progress: surfaceState.progress, dark: dark),
            green: EEDCSidebarGeometry.surfaceComponent(base: green, progress: surfaceState.progress, dark: dark),
            blue: EEDCSidebarGeometry.surfaceComponent(base: blue, progress: surfaceState.progress, dark: dark),
            alpha: alpha
        )
    }
}
extension Notification.Name {
    static let eedcSidebarWillOpen = Notification.Name("eedc.sidebar.willOpen")
}

private struct EEDCRailGlass: ViewModifier {
    let capsule: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if capsule { content.glassEffect(.regular.interactive(), in: Capsule()) }
            else { content.glassEffect(.regular.interactive(), in: Circle()) }
        } else {
            if capsule { content.background(.ultraThinMaterial, in: Capsule()) }
            else { content.background(.ultraThinMaterial, in: Circle()) }
        }
    }
}

private struct EEDCTerminalIcon: View {
    var body: some View {
        Image(systemName: "apple.terminal")
            .font(.system(size: 25, weight: .regular))
            .environment(\.legibilityWeight, .regular)
            .frame(width: 56, height: 56)
    }
}

private struct EEDCWindowMetrics: Equatable {
    var height: CGFloat = 0
    var safeTop: CGFloat = 0
}

private struct EEDCWindowCornerProbe: UIViewRepresentable {
    @Binding var radius: CGFloat
    @Binding var metrics: EEDCWindowMetrics

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onRadius = { value in
            DispatchQueue.main.async {
                if abs(radius - value) > 0.5 { radius = value }
            }
        }
        view.onMetrics = { value in
            DispatchQueue.main.async {
                if metrics != value { metrics = value }
            }
        }
        return view
    }

    func updateUIView(_ view: Probe, context: Context) { view.resolveRadius() }

    final class Probe: UIView {
        var onRadius: ((CGFloat) -> Void)?
        var onMetrics: ((EEDCWindowMetrics) -> Void)?
        private weak var measuredWindow: UIWindow?
        private var measuredBounds: CGRect?
        private var measuredSafeInsets: UIEdgeInsets?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolveRadius()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            resolveRadius()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            resolveRadius()
        }

        func resolveRadius() {
            guard let window, measuredWindow !== window || measuredBounds != window.bounds || measuredSafeInsets != window.safeAreaInsets else { return }
            measuredWindow = window
            measuredBounds = window.bounds
            measuredSafeInsets = window.safeAreaInsets
            onMetrics?(EEDCWindowMetrics(height: window.bounds.height, safeTop: window.safeAreaInsets.top))
            if #available(iOS 26.0, *) {
                let reference = UIView(frame: window.bounds)
                reference.backgroundColor = .clear
                reference.isUserInteractionEnabled = false
                reference.isAccessibilityElement = false
                reference.accessibilityElementsHidden = true
                reference.cornerConfiguration = .uniformCorners(radius: .containerConcentric())
                window.addSubview(reference)
                reference.layoutIfNeeded()
                let value = reference.effectiveRadius(corner: .topLeft)
                reference.removeFromSuperview()
                if value.isFinite { onRadius?(max(0, value)) }
            }
        }
    }
}

private struct EEDCSidebarContainer<Content: View, History: View, Actions: View>: View {
    @Binding var sidebar: EEDCSidebar
    @State private var drag: CGFloat = 0
    // Keep stable identity; only the background leaf observes reveal progress.
    @State private var surfaceState = EEDCSidebarSurfaceState()
    @State private var windowCornerRadius: CGFloat = 36
    @State private var windowMetrics = EEDCWindowMetrics()
    @Environment(\.accessibilityReduceMotion) private var eedcReduceMotion
    let content: Content
    let history: History
    let actions: (CGFloat, CGFloat, CGFloat, CGFloat) -> Actions

    init(sidebar: Binding<EEDCSidebar>, content: Content, history: History,
         @ViewBuilder actions: @escaping (CGFloat, CGFloat, CGFloat, CGFloat) -> Actions) {
        self._sidebar = sidebar
        self.content = content
        self.history = history
        self.actions = actions
    }

    var body: some View {
        GeometryReader { geometry in
            let historyWidth = EEDCSidebarGeometry.historyWidth(for: geometry.size.width)
            let actionWidth = EEDCSidebarGeometry.actionWidth
            let base: CGFloat = sidebar == .history ? historyWidth : (sidebar == .actions ? -actionWidth : 0)
            let start = sidebar == .history ? 1 : (sidebar == .actions ? -1 : 0)
            let offset = EEDCSidebarGeometry.clampedOffset(base + drag, start: start, historyWidth: historyWidth, actionWidth: actionWidth)
            let historyProgress = max(0, offset / historyWidth)
            let outlineProgress = EEDCSidebarGeometry.revealProgress(offset: offset, historyWidth: historyWidth, actionWidth: actionWidth)
            let frame = geometry.frame(in: .global)
            let safeTop = windowMetrics.height > 0 ? windowMetrics.safeTop : max(geometry.safeAreaInsets.top, frame.minY)
            let topGap = max(0, frame.minY)
            let bottomGap = windowMetrics.height > 0 ? max(0, windowMetrics.height - frame.maxY) : geometry.safeAreaInsets.bottom
            let cardHeight = EEDCSidebarGeometry.cardHeight(geometryHeight: geometry.size.height, topGap: topGap, bottomGap: bottomGap)
            let cardVerticalOffset = EEDCSidebarGeometry.cardVerticalOffset(topGap: topGap, bottomGap: bottomGap)
            ZStack {
                ChatColors.background.ignoresSafeArea()
                ZStack {
                    history
                        .frame(width: historyWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(historyProgress > 0 ? 1 : 0)
                        .allowsHitTesting(sidebar == .history && drag == 0)
                    actions(safeTop, frame.minY, bottomGap, windowCornerRadius)
                        .frame(width: actionWidth)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .opacity(offset < 0 ? Double(0.25 + 0.75 * min(1, -offset / actionWidth)) : 0)
                        .allowsHitTesting(sidebar == .actions && drag == 0)
                }
                content
                    .environment(\.eedcWindowCornerRadius, windowCornerRadius)
                    .environment(\.eedcSidebarSurfaceState, surfaceState)
                    .frame(width: geometry.size.width, height: cardHeight)
                    .background(ChatColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(Double(0.16 * outlineProgress)), lineWidth: 0.75)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        if sidebar != .closed {
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(eedcReduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) { sidebar = .closed }
                                }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                            .fill(ChatColors.background)
                            .shadow(color: .black.opacity(Double(0.06 * outlineProgress)), radius: 8, x: 0, y: 3)
                    }
                    .scaleEffect(EEDCSidebarGeometry.scale(for: historyProgress))
                    // Scaling is around the center; compensate its left inset
                    // so the card edge remains aligned with the revealed rail.
                    .offset(x: EEDCSidebarGeometry.cardOffset(offset, width: geometry.size.width, progress: historyProgress), y: cardVerticalOffset)
            }
            .onAppear { surfaceState.update(progress: outlineProgress) }
            .onChange(of: outlineProgress) { surfaceState.update(progress: $0) }
            .coordinateSpace(name: "eedc-sidebar-container")
            .simultaneousGesture(sidebarGesture(width: geometry.size.width, historyWidth: historyWidth, actionWidth: actionWidth))
            .background(EEDCWindowCornerProbe(radius: $windowCornerRadius, metrics: $windowMetrics))
        }
    }

    private func sidebarGesture(width: CGFloat, historyWidth: CGFloat, actionWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("eedc-sidebar-container"))
            .onChanged { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                let validStart = sidebar != .closed || value.startLocation.x < 32 || value.startLocation.x > width - 32
                guard horizontal && validStart else { return }
                let opening = sidebar == .closed && ((value.startLocation.x < 32 && value.translation.width > 0)
                    || (value.startLocation.x > width - 32 && value.translation.width < 0))
                if opening && drag == 0 {
                    NotificationCenter.default.post(name: .eedcSidebarWillOpen, object: nil)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                if sidebar == .closed {
                    if value.startLocation.x < 32 { drag = max(0, value.translation.width) }
                    else { drag = min(0, value.translation.width) }
                } else {
                    drag = value.translation.width
                }
            }
            .onEnded { value in
                guard drag != 0 else { return }
                let base: CGFloat = sidebar == .history ? historyWidth : (sidebar == .actions ? -actionWidth : 0)
                let projected = base + value.predictedEndTranslation.width
                let start = sidebar == .history ? 1 : (sidebar == .actions ? -1 : 0)
                let destination = EEDCSidebarGeometry.destination(projected: projected, start: start, historyWidth: historyWidth, actionWidth: actionWidth)
                withAnimation(eedcReduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                    if destination == 1 { sidebar = .history }
                    else if destination == -1 { sidebar = .actions }
                    else { sidebar = .closed }
                    drag = 0
                }
            }
    }

}

extension ContentView {
    // Keep the existing navigation tree mounted while exposing the two rails.
    func eedcLayout<Content: View>(content: Content) -> some View {
        EEDCSidebarContainer(sidebar: $eedcSidebar, content: content,
                             history: NavigationStack { sessionList(useNavigationLinks: true, historyOnly: true) }) { safeTop, originTop, bottomGap, radius in
            eedcActions(safeTop: safeTop, originTop: originTop, bottomGap: bottomGap, windowRadius: radius)
        }
    }
    private func eedcActions(safeTop: CGFloat, originTop: CGFloat, bottomGap: CGFloat, windowRadius: CGFloat) -> some View {
        let bottom = EEDCSidebarGeometry.settingsBottom(radius: windowRadius, bottomInset: bottomGap)
        let settingsShift = EEDCSidebarGeometry.settingsShift(radius: windowRadius)
        return VStack {
            VStack(spacing: 0) {
                eedcAction("新会话", symbol: "message") { handleNewChatRequest() }
                eedcAction("搜索", symbol: "magnifyingglass") {
                    withAnimation(eedcReduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .history }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focusSearch() }
                }
                Button {
                    withAnimation(eedcReduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .closed }
                    showTerminal = true
                } label: {
                    EEDCTerminalIcon()
                }.accessibilityLabel("终端")
            }
            .modifier(EEDCRailGlass(capsule: true))
            Spacer()
            eedcAction("设置", symbol: "gearshape") { activeToolSheet = .settings }
                .modifier(EEDCRailGlass(capsule: false))
                .offset(x: settingsShift)
        }
        .foregroundStyle(.primary)
        .padding(.top, EEDCSidebarGeometry.railTop(radius: windowRadius, safeTop: safeTop, originTop: originTop))
        .padding(.bottom, bottom)
    }

    private func eedcAction(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            if label != "搜索" {
                withAnimation(eedcReduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .closed }
            }
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 25)).frame(width: 56, height: 56)
        }.accessibilityLabel(label)
    }

    // MARK: - Split Layout (iPad / wide window)

    var splitLayout: some View {
        // [T-ios-gh29-font-scale-split-column] App-base font scale for the iPad
        // split view. `appFontScale()` is environment-based (`.dynamicTypeSize`),
        // and SwiftUI environment does NOT bridge across NavigationSplitView's
        // per-column UIHostingController boundaries — applying it on the
        // container (the previous GH#29 fix) left the column contents unscaled,
        // which is why the font slider still didn't take effect on iPad/Mac.
        // Apply it INSIDE each column instead so the modifier lands on the
        // hosting boundary's inner side and reaches the content. The earlier
        // session-switch / tap lag is a separate issue (ChatSession Array `==`
        // in SwiftUI's transaction flush; an A/B test confirmed the font
        // injection is not its cause), so per-column injection is safe here.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sessionList(useNavigationLinks: false)
                .appFontScale()
        } detail: {
            detailView
                .appFontScale()
        }
    }

    // MARK: - Stack Layout (iPhone / narrow window)

    var stackLayout: some View {
        NavigationStack(path: $navigationPath) {
            AIChatView()
                .navigationDestination(for: String.self) { id in
                    // `.id(id)` mirrors detailView (iPad): navigationDestination
                    // views are identified by stack depth, not path value, so
                    // replacing the top element in place (menu "New Chat" swaps
                    // [current] → [draft]) would otherwise reuse the old view's
                    // @StateObject vm and nothing visibly changes.
                    if id.hasPrefix("remote:") {
                        let parts = id.split(separator: ":", maxSplits: 2)
                        if parts.count == 3 {
                            AIChatView(sessionId: String(parts[2]), remoteDeviceId: String(parts[1]))
                                .id(id)
                                .navigationBarBackButtonHidden(true)
                        }
                    } else {
                        AIChatView(sessionId: Self.isNewSessionId(id) ? nil : id, draftId: Self.isNewSessionId(id) ? id : nil, initialGroupId: Self.extractGroupId(from: id))
                            .id(id)
                            .navigationBarBackButtonHidden(true)
                            .onAppear {
                                if currentStackSessionId != id {
                                    currentStackSessionId = id
                                    // [T-ios-stacknav-transition-attributegraph-race]
                                    // Keep the outgoing-id tracker in lockstep.
                                    // This branch fires exactly when the two
                                    // have DIVERGED — the "swallowed push left
                                    // currentStackSessionId set to a target
                                    // that never appeared" case documented on
                                    // the .moveInputToSession handler — and it
                                    // mounts a chat WITHOUT a navigationPath
                                    // change, so the observer that normally
                                    // maintains previousStackSessionId does not
                                    // run. Left unsynced, the next real
                                    // transition would suspend whichever id the
                                    // last observer pass recorded instead of
                                    // the vm actually on screen: the wrong vm
                                    // stalls and the real outgoing one keeps
                                    // publishing into its teardown.
                                    previousStackSessionId = id
                                }
                                SessionBadgeStore.shared.remove(.unread, for: id)
                                shareLog.info("🔄SESSION stackNav APPEAR id=\(id)")
                                HangDetector.mark("chat appear")  // [T-main-stall-marks]
                            }
                            .onDisappear {
                                shareLog.info("🔄SESSION stackNav DISAPPEAR id=\(id)")
                                HangDetector.mark("chat disappear")  // [T-main-stall-marks]
                            }
                    }
                }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedSessionId {
            // Draft sessions always pass nil — the VM creates a real session internally
            // on first send. The .id() ensures each draft gets its own View lifecycle.
            let isDraft = Self.isNewSessionId(id)
            let effectiveId: String? = isDraft ? nil : id
            AIChatView(sessionId: effectiveId, draftId: isDraft ? id : nil, initialGroupId: Self.extractGroupId(from: id))
                .id(id)
                .onAppear {
                    draftLog.info("🔑DRAFT detailView APPEAR id=\(id) effectiveId=\(effectiveId ?? "nil") isDraft=\(isDraft)")
                }
                .onDisappear {
                    draftLog.info("🔑DRAFT detailView DISAPPEAR id=\(id)")
                }
        } else {
            AIChatView()
        }
    }
}
