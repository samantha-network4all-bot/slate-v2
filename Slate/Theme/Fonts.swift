import AppKit

enum Fonts {
    static let chrome        = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let chromeBold    = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let statusBar     = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let editorDefault: NSFont = {
        NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11) ?? NSFont.systemFont(ofSize: 11)
    }()
    static let dialogLabel   = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let dialogTitle   = NSFont.systemFont(ofSize: 13, weight: .semibold)
}
