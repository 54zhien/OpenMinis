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

private let shareLog = AppLogger(category: "Share")
private let draftLog = AppLogger(category: "DraftSession")

enum EEDCSidebar { case closed, history, actions }

extension ContentView {
    // Keep the existing navigation tree mounted while exposing the two rails.
    func eedcLayout<Content: View>(content: Content, wide: Bool) -> some View {
        GeometryReader { geometry in
            let historyWidth = min(geometry.size.width * 0.78, 340)
            let actionWidth: CGFloat = 96
            let base: CGFloat = eedcSidebar == .history ? historyWidth : (eedcSidebar == .actions ? -actionWidth : 0)
            let offset = min(historyWidth, max(-actionWidth, base + eedcDrag))
            let historyProgress = max(0, offset / historyWidth)
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                HStack(spacing: 0) {
                    NavigationStack { sessionList(useNavigationLinks: false) }
                        .frame(width: historyWidth)
                        .opacity(historyProgress > 0 ? 1 : 0)
                        .allowsHitTesting(eedcSidebar == .history && eedcDrag == 0)
                    Spacer(minLength: 0)
                    eedcActions(topInset: geometry.safeAreaInsets.top, bottomInset: geometry.safeAreaInsets.bottom)
                        .frame(width: actionWidth)
                        .opacity(offset < 0 ? Double(0.25 + 0.75 * min(1, -offset / actionWidth)) : 0)
                        .allowsHitTesting(eedcSidebar == .actions && eedcDrag == 0)
                }
                content
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 36 * max(historyProgress, min(1, abs(offset) / actionWidth)), style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 36 * max(historyProgress, min(1, abs(offset) / actionWidth)), style: .continuous)
                            .strokeBorder(Color.primary.opacity(offset == 0 ? 0 : 0.16), lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        if eedcSidebar != .closed {
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .closed }
                                }
                        }
                    }
                    .scaleEffect(1 - 0.15 * historyProgress)
                    .offset(x: offset)
                    .simultaneousGesture(eedcSidebarGesture(width: geometry.size.width, historyWidth: historyWidth, actionWidth: actionWidth))
            }
            .clipped()
            .onChange(of: selectedSessionId) { id in
                guard eedcSidebar == .history, let id else { return }
                if !wide {
                    commitNavigationPath(NavigationPath([id]), target: id)
                    currentStackSessionId = id
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .closed }
            }
        }
    }

    private func eedcSidebarGesture(width: CGFloat, historyWidth: CGFloat, actionWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                let validStart = eedcSidebar != .closed || value.startLocation.x < 32 || value.startLocation.x > width - 32
                guard horizontal && validStart else { return }
                if eedcSidebar == .closed {
                    if value.startLocation.x < 32 { eedcDrag = max(0, value.translation.width) }
                    else { eedcDrag = min(0, value.translation.width) }
                } else {
                    eedcDrag = value.translation.width
                }
            }
            .onEnded { value in
                guard eedcDrag != 0 else { return }
                let base: CGFloat = eedcSidebar == .history ? historyWidth : (eedcSidebar == .actions ? -actionWidth : 0)
                let projected = base + value.predictedEndTranslation.width
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    if projected > historyWidth * 0.45 { eedcSidebar = .history }
                    else if projected < -actionWidth * 0.45 { eedcSidebar = .actions }
                    else { eedcSidebar = .closed }
                    eedcDrag = 0
                }
            }
    }

    private func eedcActions(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        VStack {
            VStack(spacing: 0) {
                eedcAction("新会话", symbol: "message") { handleNewChatRequest() }
                eedcAction("搜索", symbol: "magnifyingglass") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { eedcSidebar = .history }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focusSearch() }
                }
                Button {
                    eedcSidebar = .closed
                    showTerminal = true
                } label: {
                    Image("TerminalCircle").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 25, height: 25).frame(width: 56, height: 56)
                }.accessibilityLabel("终端")
            }
            .glassEffect(.regular.interactive(), in: Capsule())
            Spacer()
            eedcAction("设置", symbol: "gearshape") { activeToolSheet = .settings }
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .foregroundStyle(.primary)
        .padding(.top, topInset + 12)
        .padding(.bottom, bottomInset + 16)
    }

    private func eedcAction(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            if label != "搜索" { eedcSidebar = .closed }
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
            sessionList(useNavigationLinks: true)
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
                        }
                    } else {
                        AIChatView(sessionId: Self.isNewSessionId(id) ? nil : id, draftId: Self.isNewSessionId(id) ? id : nil, initialGroupId: Self.extractGroupId(from: id))
                            .id(id)
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
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Conversation Selected")
                    .font(.title3.bold())
                Text("Select a conversation or start a new one")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
