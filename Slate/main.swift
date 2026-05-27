import AppKit

// Explicit bootstrap — no @main, no lazy NSApplicationMain.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

// Start test API if SLATE_TEST_API=1
TestAPIServer.shared.start()

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
