import Foundation

let iosRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let path = iosRoot.appendingPathComponent("Views/Chat/AIChatView/Composer/ComposerThinkingArcGeometry.swift")
let source = try String(contentsOf: path, encoding: .utf8)
let checks = """

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError(message) }
}
for size in [CGSize(width: 260, height: 90), CGSize(width: 340, height: 120)] {
    let curve = ComposerThinkingArcGeometry(size: size, inset: 20)
    let left = curve.point(at: 0)
    let middle = curve.point(at: 0.5)
    let right = curve.point(at: 1)
    check(left.x < middle.x && middle.x < right.x, "detents must run left to right")
    check(middle.y < left.y && middle.y < right.y, "thinking rail must arch upwards")
    for index in 0...20 {
        let fraction = Double(index) / 20
        let point = curve.point(at: fraction)
        check(abs(curve.projectedFraction(at: point) - fraction) < 0.0001, "drag projection must follow the rendered rail")
    }
}
print("Thinking rail geometry checks passed")
"""
let file = FileManager.default.temporaryDirectory.appendingPathComponent("eedc-rail-\(UUID().uuidString).swift")
try (source + checks).write(to: file, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: file) }
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
task.arguments = ["swift", file.path]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
