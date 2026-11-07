import Foundation

let iosRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let path = iosRoot.appendingPathComponent("Views/ContentView/ContentView+Layout.swift")
let source = try String(contentsOf: path, encoding: .utf8)
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
check(near(EEDCSidebarGeometry.scale(for: 1), 0.95), "open history scales card to 95 percent")
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
