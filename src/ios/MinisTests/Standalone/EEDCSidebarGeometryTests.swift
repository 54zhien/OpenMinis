import Foundation

let iosRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let path = iosRoot.appendingPathComponent("Views/ContentView/ContentView+Layout.swift")
let source = try String(contentsOf: path, encoding: .utf8)
let chatSource = try String(contentsOf: iosRoot.appendingPathComponent("Views/Chat/AIChatView/AIChatView.swift"), encoding: .utf8)
let colorSource = try String(contentsOf: iosRoot.appendingPathComponent("Views/Chat/AIChatView/Support/ChatColors.swift"), encoding: .utf8)
guard let start = source.range(of: "enum EEDCSidebarGeometry {"),
      let end = source.range(of: "\n\nprivate struct EEDCWindowCornerRadiusKey", range: start.lowerBound..<source.endIndex) else {
    fatalError("Sidebar geometry is missing")
}
let geometry = String(source[start.lowerBound..<end.lowerBound])
let harness = "import Foundation\n" + geometry + """

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError(name) }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.001 }
check(near(EEDCSidebarGeometry.actionWidth, 96), "right rail matches Zen width")
check(near(EEDCSidebarGeometry.scale(for: 0), 1), "closed card is full size")
check(near(EEDCSidebarGeometry.scale(for: 1), 0.98), "open history scales card to 98 percent")
check(near(EEDCSidebarGeometry.scale(for: 0.5), 0.99), "history scale follows partial gesture progress")
check(near(EEDCSidebarGeometry.scale(for: 2), 0.98), "history scale clamps at the open endpoint")
check(near(EEDCSidebarGeometry.revealProgress(offset: 150, historyWidth: 300, actionWidth: 96), 0.5), "history tint follows normalized progress")
check(near(EEDCSidebarGeometry.revealProgress(offset: -48, historyWidth: 300, actionWidth: 96), 0.5), "action tint follows normalized progress")
check(near(EEDCSidebarGeometry.cardHeight(geometryHeight: 707, topGap: 59, bottomGap: 34), 800), "card surface fills the measured window")
check(near(EEDCSidebarGeometry.cardVerticalOffset(topGap: 59, bottomGap: 34), -12.5), "safe-area card frame centers on the window")
check(near(EEDCSidebarGeometry.cardHeight(geometryHeight: 451, topGap: 59, bottomGap: 334), 844), "keyboard safe-area gap restores the card shell to window height")
check(near(EEDCSidebarGeometry.cardVerticalOffset(topGap: 59, bottomGap: 334), 137.5), "keyboard safe-area gap centers the card shell on the window")
check(near(EEDCSidebarGeometry.cardHeight(geometryHeight: 800, topGap: 0, bottomGap: 0), 800), "full-window layout keeps its measured height")
check(near(EEDCSidebarGeometry.cardVerticalOffset(topGap: 0, bottomGap: 0), 0), "full-window layout keeps its vertical origin")
check(near(EEDCSidebarGeometry.surfaceComponent(base: 1, progress: 0, dark: false), 0.98), "light card has a subtle off-white resting surface")
check(near(EEDCSidebarGeometry.surfaceComponent(base: 1, progress: 0.5, dark: false), 0.99), "light surface brightens smoothly")
check(near(EEDCSidebarGeometry.surfaceComponent(base: 1, progress: 1, dark: false), 1), "light surface reaches the canvas color when open")
check(near(EEDCSidebarGeometry.surfaceComponent(base: 0.5, progress: 0.5, dark: true), 0.48), "dark surface deepens smoothly")
check(near(EEDCSidebarGeometry.surfaceComponent(base: 0.5, progress: 2, dark: true), 0.46), "surface tint clamps at the open endpoint")
check(near(EEDCSidebarGeometry.clampedOffset(-500, start: 1, historyWidth: 300, actionWidth: 96), 0), "history cannot cross into actions")
check(near(EEDCSidebarGeometry.clampedOffset(500, start: -1, historyWidth: 300, actionWidth: 96), 0), "actions cannot cross into history")
check(EEDCSidebarGeometry.destination(projected: -500, start: 1, historyWidth: 300, actionWidth: 96) == 0, "history swipe closes only")
check(EEDCSidebarGeometry.destination(projected: 500, start: -1, historyWidth: 300, actionWidth: 96) == 0, "actions swipe closes only")
check(EEDCSidebarGeometry.destination(projected: 200, start: 0, historyWidth: 300, actionWidth: 96) == 1, "closed state can open history")
check(EEDCSidebarGeometry.destination(projected: -70, start: 0, historyWidth: 300, actionWidth: 96) == -1, "closed state can open actions")
check(near(EEDCSidebarGeometry.clampedOffset(120, start: 1, historyWidth: 300, actionWidth: 96), 120), "history follows a partial drag")
check(near(EEDCSidebarGeometry.clampedOffset(-40, start: -1, historyWidth: 300, actionWidth: 96), -40), "actions follow a partial drag")
let width: CGFloat = 393
let history = EEDCSidebarGeometry.historyWidth(for: width)
let translation = EEDCSidebarGeometry.cardOffset(history, width: width, progress: 1)
let scaledLeftInset = width * (1 - EEDCSidebarGeometry.scale(for: 1)) / 2
check(near(translation + scaledLeftInset, history), "scaled card edge aligns with history rail")
check(near(EEDCSidebarGeometry.cardOffset(-96, width: width, progress: 0), -96), "right rail translates without scaling")
check(near(EEDCSidebarGeometry.settingsBottom(radius: 55, bottomInset: 34) + 34 + 28, 55), "settings center shares display corner center")
check(near(48 - EEDCSidebarGeometry.settingsShift(radius: 55), 55), "settings horizontal center shares display corner center")
check(near(EEDCSidebarGeometry.railTop(radius: 55, safeTop: 59, originTop: 59) + 59, 71), "top controls do not count the safe area twice")
check(near(EEDCSidebarGeometry.railTop(radius: 55, safeTop: 59, originTop: 0), 71), "full-window layout respects the top safe area")
check(!source.contains(".fill(Color.white.opacity(Double(0.08 * outlineProgress)))"), "card tint does not cover chat contents")
check(chatSource.contains(".background(EEDCCardSurfaceBackground())"), "chat surface tint stays in its background leaf")
check(colorSource.contains("UIColor(white: 0.055, alpha: 1)"), "dark global surface is lighter than pure black")
check(source.contains(".environment(\\.legibilityWeight, .regular)"), "terminal symbol keeps regular weight with bold text enabled")
check(source.contains("cardVerticalOffset"), "card extends through the window safe areas")
check(source.contains(".frame(width: geometry.size.width, height: cardHeight)"), "card geometry includes both window safe-area gaps")
check(source.contains(".offset(x: EEDCSidebarGeometry.cardOffset") && source.contains("y: cardVerticalOffset"), "card geometry applies the measured vertical origin")
check(source.contains("private struct EEDCSurfaceColorModifier: ViewModifier, Animatable") && source.contains("var animatableData: CGFloat"), "surface color interpolates with the sidebar spring")
check(source.contains(".environment(\\.eedcSidebarSurfaceProgress, outlineProgress)"), "drag progress is isolated to the surface leaf")
check(chatSource.contains(".safeAreaInset(edge: .bottom, spacing: 0)") && !source.contains("ignoresSafeArea(.keyboard"), "sidebar frame keeps keyboard avoidance active")
print("Sidebar geometry checks passed")
"""
let file = FileManager.default.temporaryDirectory.appendingPathComponent("eedc-sidebar-\(UUID().uuidString).swift")
try harness.write(to: file, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: file) }
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
task.arguments = ["swift", file.path]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
