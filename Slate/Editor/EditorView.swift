import AppKit

class EditorView: NSTextView {

    init() {
        // Canonical chain: NSTextStorage → NSLayoutManager → NSTextContainer → NSTextView
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: .zero, textContainer: textContainer)

        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isRichText = false
        isEditable = true
        isSelectable = true
        allowsUndo = true
        font = Fonts.editorDefault
        textColor = Colors.editorText
        backgroundColor = Colors.editorBg
        insertionPointColor = NSColor.black
        selectedTextAttributes = [
            .backgroundColor: Colors.selectionBg,
            .foregroundColor: Colors.selectionText
        ]
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
    }
}
