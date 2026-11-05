import Foundation

let iosRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let path = iosRoot.appendingPathComponent("Views/Chat/AIChatView/AIChatView+InputPopups.swift")
let source = try String(contentsOf: path, encoding: .utf8)
guard let start = source.range(of: "enum EEDCKeyboardMenuPhase {"),
      let end = source.range(of: "\n\nprivate enum EEDCMenuLevel", range: start.lowerBound..<source.endIndex) else {
    fatalError("Keyboard handoff state is missing")
}
let state = String(source[start.lowerBound..<end.lowerBound])
let harness = state + """

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError(name) }
}
check(EEDCKeyboardMenuPhase.waitingForHide.shouldResignKeyboard, "opening must request keyboard dismissal")
check(!EEDCKeyboardMenuPhase.shown.shouldResignKeyboard, "shown menu must not dismiss again")
check(EEDCKeyboardMenuPhase.waitingForHide.afterKeyboardDidHide(isFocused: true) == nil, "ignore hide while editor still owns focus")
check(EEDCKeyboardMenuPhase.waitingForHide.afterKeyboardDidHide(isFocused: false) == .shown, "show menu after keyboard hides")
check(EEDCKeyboardMenuPhase.restoreAfterHide.afterKeyboardDidHide(isFocused: false) == .restoring, "restore keyboard after quick reversal")
check(EEDCKeyboardMenuPhase.closed.afterKeyboardDidHide(isFocused: false) == nil, "ignore unrelated hide")
print("Keyboard handoff state checks passed")
"""
let file = FileManager.default.temporaryDirectory.appendingPathComponent("eedc-handoff-\(UUID().uuidString).swift")
try harness.write(to: file, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: file) }
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
task.arguments = ["swift", file.path]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
