# PRD — Slate (Windows 10 Notepad style, for macOS)

> **Audience.** This document is the contract between the product
> owner and the orchestrator-driven LLM coding fleet. It is the
> only place where behavior is decided. The orchestrator turns each
> section into a series of GitHub issues; the coding agents
> implement them one slice at a time; the feature-test check proves
> each slice via the local HTTP API (§7).
>
> **Hard rules.** Do not invent behavior, colors, sizes, or libraries
> outside this document. Do not skip §8 — those invariants are
> derived from real shipped bugs. If a question arises that this
> document does not answer, the agent must reject the issue rather
> than guess.

---

## 0. Reading order

1. §1 Product Overview and §2 Tech Stack tell you *what* is being
   built and with what tools.
2. §3 Project Structure tells you *where* code lives.
3. §4 Visual Design tells you *what it looks like* (colors, sizes).
4. §5 Behavior tells you *what it does*.
5. §6 Files & Encoding tells you *how persistence works*.
6. **§7 Testability is the contract with the orchestrator.** Every
   issue must include an HTTP probe under one of these endpoints.
7. **§8 Architectural invariants are derived from
   [`lessons-learned.md`](./lessons-learned.md).** Code review
   blocks PRs that violate them.

---

## 1. Product Overview

### 1.1 What we are building
A native macOS application named **Slate** that visually and
behaviorally recreates Microsoft's Windows 10 Notepad (version
1909+ — the one with the status bar showing `Ln/Col`, zoom %,
line ending, and encoding segments). "Slate" is the codename and
the bundle identifier; the chrome may still display the word
"Notepad" in the title bar where the reference UI does.

### 1.2 Reference
The reference image used during initial design lives in the legacy
[`notepad/` repo](https://github.com/samantha-network4all-bot/slate) as
`notepad.png`. It shows the window has:

- A white title bar with `Untitled - Notepad` on the left and
  minimize / maximize / close buttons on the right.
- A menu bar with `File  Edit  Format  View  Help` (Alt-accelerator
  underlines hidden by default).
- A white text editing area.
- A status bar at the bottom showing `Ln 1, Col 1`, then on the
  right `100%`, `Windows (CRLF)`, `UTF-8`.

The PRD prose below is authoritative; the image is for orientation only.

### 1.3 In scope
- Pixel-faithful Win10 chrome (custom borderless `NSWindow`).
- All five top-level menus fully functional.
- File I/O with UTF-8, UTF-8 BOM, UTF-16 LE, UTF-16 BE.
- Line-ending detection (CRLF, LF, CR) and conversion.
- Multi-window: each document is a separate window.
- Drag-and-drop of `.txt` files onto a window opens the file.
- Registered as a `.txt` handler in `Info.plist`.
- Custom always-visible Win10-style scrollbars with arrow buttons.
- Alt-key accelerator support (underlines appear while Alt is held).
- macOS top menu bar mirrors the in-window menus.
- Both ⌘ and Ctrl keyboard shortcuts are accepted.
- Local-loopback HTTP test API (§7) for headless verification.

### 1.4 Out of scope (for v1)
- Tabs (Win11 feature).
- Dark mode (always light).
- Auto-save / crash recovery.
- Spell check, syntax highlighting, regex find.
- Cloud sync, telemetry, updates.
- Bundling Windows fonts (macOS substitutes are fine).
- Custom app icon (Xcode default).
- Print sheet customisation (use the macOS print sheet).
- **Custom Win10-style file dialogs.** v1 uses `NSOpenPanel` and
  `NSSavePanel`. A Win10-styled file dialog is a *future* set of
  S-issues, not bundled with File→Open. See lessons §1.7.

### 1.5 Success criteria
A user can perform any task that real Windows 10 Notepad supports,
the visual output is recognisably "Notepad" (not a Mac text editor
in disguise), and the entire feature surface is reachable from the
HTTP test API so a CI-style check can verify it without a human.

---

## 2. Tech Stack (locked, do not deviate)

| Item               | Choice |
|--------------------|--------|
| Language           | Swift 5.9+ |
| UI framework       | AppKit (no SwiftUI) |
| Build system       | Xcode project generated from `Project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen) |
| Build command      | `xcodegen generate && xcodebuild -scheme Slate -configuration Debug -derivedDataPath build/` |
| Minimum macOS      | 13.0 (Ventura) |
| Architecture       | Universal (arm64 + x86_64) |
| Third-party deps   | **None.** Standard library + AppKit only. No SPM, no CocoaPods. |
| Bundle ID          | `com.bimboware.slate` |
| App display name   | `Slate` (`CFBundleDisplayName`); window title shows `Untitled - Notepad` per the reference UI |
| Window class       | `NSWindow` subclass with `styleMask = [.borderless, .resizable, .miniaturizable]` |
| App entry          | Explicit `Slate/main.swift` (no `@main` — see §8.1) |
| Test API           | `URLSession`-free, `Foundation`-only HTTP server bound to `127.0.0.1` on a port chosen at launch. See §7. |

---

## 3. Project Structure

```
slate/
├── PRD.md                        (this file — never edited by agents)
├── lessons-learned.md            (also never edited by agents)
├── README.md
├── .gitignore
├── Project.yml                   (xcodegen spec; tracked in git)
├── orchestrator/                 (Go module — out of scope for coding agents)
└── Slate/                        (app source root)
    ├── main.swift
    ├── AppDelegate.swift
    ├── Info.plist
    ├── Assets.xcassets/
    │
    ├── App/
    │   ├── DocumentController.swift   (spawns windows, tracks open docs)
    │   ├── MenuBuilder.swift          (builds macOS top menu bar)
    │   └── KeyboardShortcuts.swift    (⌘ and Ctrl acceptance)
    │
    ├── Window/
    │   ├── SlateWindow.swift          (borderless NSWindow subclass)
    │   ├── SlateWindowController.swift
    │   ├── TitleBarView.swift
    │   ├── TitleBarButton.swift
    │   ├── InWindowMenuBarView.swift
    │   ├── InWindowMenuItemView.swift
    │   ├── StatusBarView.swift
    │   └── StatusBarSegment.swift
    │
    ├── Editor/
    │   ├── EditorView.swift           (NSTextView subclass — see §8.2)
    │   ├── EditorScrollView.swift     (canonical storage→layout→container)
    │   ├── WinScroller.swift          (NSScroller subclass with arrows)
    │   ├── DocumentState.swift
    │   └── ZoomController.swift
    │
    ├── Dialogs/
    │   ├── FindSheet.swift            (NSWindow as a sheet)
    │   ├── ReplaceSheet.swift
    │   ├── GoToLineSheet.swift
    │   ├── FontSheet.swift
    │   ├── PageSetupSheet.swift
    │   ├── AboutDialog.swift
    │   └── SaveChangesPrompt.swift
    │
    ├── Files/
    │   ├── EncodingDetector.swift
    │   ├── LineEndingDetector.swift
    │   ├── DocumentReader.swift
    │   └── DocumentWriter.swift
    │
    ├── Theme/
    │   ├── Colors.swift
    │   ├── Fonts.swift
    │   └── Metrics.swift
    │
    ├── Util/
    │   ├── AltKeyMonitor.swift
    │   └── LineColumnTracker.swift
    │
    └── TestAPI/
        ├── TestAPIServer.swift        (HTTP listener; see §7)
        └── TestAPIRoutes.swift        (route handlers calling AppKit on main)
```

Notes:
- **No `FileBrowser/` subdirectory.** v1 uses macOS panels.
- **No `DialogWindow.swift` base class.** Dialogs are sheets on
  the parent window (`beginSheet`); no custom modality logic.
- **`TestAPI/` is mandatory** even at the empty-window stage so
  the feature-test check has something to call from issue S1.

---

## 4. Visual Design Specifications

All values are exact unless noted "approximate". 1pt = 1 logical
point on macOS.

### 4.1 Colors (`Theme/Colors.swift`)

```swift
enum Colors {
    static let chromeBackground    = NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1)
    static let chromeBorder        = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1)
    static let chromeBorderHeavy   = NSColor(srgbRed: 0.67, green: 0.67, blue: 0.67, alpha: 1)
    static let chromeText          = NSColor.black
    static let chromeTextInactive  = NSColor(srgbRed: 0.67, green: 0.67, blue: 0.67, alpha: 1)

    static let menuHoverBg         = NSColor(srgbRed: 0.90, green: 0.95, blue: 1.00, alpha: 1)
    static let menuActiveBg        = NSColor(srgbRed: 0.80, green: 0.91, blue: 1.00, alpha: 1)
    static let menuSeparator       = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1)

    static let statusBarBg         = NSColor(srgbRed: 0.94, green: 0.94, blue: 0.94, alpha: 1)
    static let statusBarSeparator  = NSColor(srgbRed: 0.84, green: 0.84, blue: 0.84, alpha: 1)

    static let editorBg            = NSColor.white
    static let editorText          = NSColor.black
    static let selectionBg         = NSColor(srgbRed: 0.00, green: 0.47, blue: 0.84, alpha: 1)
    static let selectionText       = NSColor.white

    static let closeButtonHover    = NSColor(srgbRed: 0.91, green: 0.07, blue: 0.14, alpha: 1)
    static let titleBarButtonHover = NSColor(srgbRed: 0.90, green: 0.90, blue: 0.90, alpha: 1)

    static let scrollbarTrack      = NSColor(srgbRed: 0.94, green: 0.94, blue: 0.94, alpha: 1)
    static let scrollbarThumb      = NSColor(srgbRed: 0.80, green: 0.80, blue: 0.80, alpha: 1)
    static let scrollbarThumbHover = NSColor(srgbRed: 0.65, green: 0.65, blue: 0.65, alpha: 1)
    static let scrollbarArrow      = NSColor(srgbRed: 0.32, green: 0.32, blue: 0.32, alpha: 1)
}
```

### 4.2 Fonts (`Theme/Fonts.swift`)

```swift
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
```

(Note: the legacy PRD had a force-unwrap fallback; per lessons §1.x
no force-unwraps on font lookup.)

### 4.3 Metrics (`Theme/Metrics.swift`)

```swift
enum Metrics {
    static let titleBarHeight: CGFloat        = 32
    static let titleBarButtonWidth: CGFloat   = 46
    static let titleBarButtonHeight: CGFloat  = 32
    static let titleBarIconSize: CGFloat      = 10
    static let titleBarPaddingLeft: CGFloat   = 12

    static let menuBarHeight: CGFloat         = 22
    static let menuItemPaddingH: CGFloat      = 8

    static let statusBarHeight: CGFloat       = 22
    static let statusSegmentPaddingH: CGFloat = 8

    static let defaultWindowSize              = NSSize(width: 900, height: 700)

    static let scrollbarThickness: CGFloat    = 17
    static let scrollbarArrowButtonHeight: CGFloat = 17
    static let scrollbarMinThumbLength: CGFloat    = 17
}
```

### 4.4 Title bar
- 32pt tall. Left text in `chrome` font, color `chromeText`. Left
  padding 12pt.
- Three right-aligned buttons, each 46×32pt: minimize (horizontal
  line, 10pt wide), maximize (10×10pt outlined square), close (X
  in 10×10pt box).
- Hover backgrounds: `titleBarButtonHover` for min/max,
  `closeButtonHover` for close (close glyph becomes white).
- Bottom 1pt line in `chromeBorder`.
- Drag anywhere except buttons moves window. Double-click zooms.

### 4.5 In-window menu bar
- 22pt tall, white, with 1pt `chromeBorder` bottom rule.
- Items are `File  Edit  Format  View  Help`; 8pt horizontal padding.
- Hover bg `menuHoverBg`. Click bg `menuActiveBg` and pops up an
  `NSMenu` via `popUp(positioning:at:in:)`.
- Accelerator letter underlined only while Alt is held (see
  `Util/AltKeyMonitor.swift`).

### 4.6 Status bar
- 22pt tall, `statusBarBg`, 1pt `chromeBorder` top rule.
- Left: `Ln N, Col M`, padded 8pt.
- Right-aligned segments in order: `<zoom>%`, `<line-ending-label>`,
  `<encoding-label>`. 1pt separator between, 8pt padding each side.
- Clicking a right segment pops an `NSMenu` directly above it.
  - **Zoom**: Zoom In (⌘+), Zoom Out (⌘-), Restore Default (⌘0).
  - **Line ending**: Windows (CRLF), Unix (LF), Macintosh (CR).
  - **Encoding**: UTF-8, UTF-8 with BOM, UTF-16 LE, UTF-16 BE.

### 4.7 Scrollbars (`Editor/WinScroller.swift`)
- Subclass `NSScroller`. Always visible (`scrollerStyle = .legacy`).
- Track color `scrollbarTrack`; thumb `scrollbarThumb` →
  `scrollbarThumbHover` on hover/drag. No rounded corners.
- 17×17pt arrow buttons at each end with `scrollbarArrow` triangle
  glyphs (5pt × 3pt). Click = scroll one line; click-and-hold
  repeats every 50ms after 300ms initial delay.

---

## 5. Application Behavior

### 5.1 Launch
- First launch: open one untitled window. Position top-right
  against `screen.visibleFrame` (top edge at `visibleFrame.maxY`,
  right edge at `visibleFrame.maxX`); size `Metrics.defaultWindowSize`.
- Subsequent launches: restore from `UserDefaults` key
  `lastFrame.0` (x/y/w/h). If `NSScreen.main` is nil at restore
  time, fall back to first-launch coordinates — do **not** force-unwrap.

### 5.2 Multi-window
- File → New (⌘N / Ctrl+N): new untitled window.
- File → Open (⌘O / Ctrl+O): `NSOpenPanel`; selected file opens in a
  **new** window.
- File → Exit (⌘Q / Ctrl+Q): quit.
- Last window closing terminates app
  (`applicationShouldTerminateAfterLastWindowClosed` returns true).

### 5.3 Title bar text
- Format: `"\(displayName) - Notepad"`.
- `displayName` = `Untitled` for unsaved docs, otherwise the file's
  last path component without extension.
- Dirty flag prefixes with `*`.

### 5.4 Menus

The menu titles, items, separators, and shortcuts are described in
the [legacy PRD](https://github.com/samantha-network4all-bot/slate)
§5.4 and apply verbatim. Briefly:

- **File**: New, Open…, Save, Save As…, separator, Page Setup…,
  Print, separator, Exit.
- **Edit**: Undo, Redo, separator, Cut, Copy, Paste, Delete,
  separator, Time/Date, separator, Find…, Find Next, Find
  Previous, Replace…, Go To Line…, separator, Select All.
- **Format**: Word Wrap (toggle, checkmark when on), Font…
- **View**: Zoom In, Zoom Out, separator, Reset Zoom, separator,
  Status Bar (toggle, default on).
- **Help**: View Help, Send Feedback, About Notepad.

Each item dispatched via macOS responder chain. ⌘ and Ctrl
modifiers both fire (KeyboardShortcuts.swift listens via
`NSEvent.addLocalMonitorForEvents`).

### 5.5 Editor
- `NSTextView` subclass `EditorView`. Construction via canonical
  storage chain (§8.2). `isRichText=false`. Undo enabled. Insertion
  point black. Selection background `selectionBg`, text
  `selectionText`.
- Word wrap default OFF. Toggling wrap is handled by `applyWordWrap()`
  on the scroll view; container width tracks text view width when
  on, otherwise container is huge and horizontal scroller appears.
- Zoom range 10%–500%, step 10% via Cmd+/- or status bar menu;
  Reset Zoom returns to 100%.

### 5.6 Find / Replace / Go To Line
- Implemented as `NSWindow` sheets attached to the parent window
  via `beginSheet(_:completionHandler:)`. No `NSApp.runModal`.
- Inline find state (search term, match case, wrap-around) persists
  across invocations on the same window in a `FindState` singleton.

### 5.7 Save / dirty handling
- A document is dirty when `textStorage.didProcessEditing` fires
  after the last save / open.
- Closing a dirty window shows `SaveChangesPrompt` (NSAlert is fine).
- Saving an untitled doc shows `NSSavePanel`.

### 5.8 Drag and drop
- Editor scroll view accepts `.fileURL` drags. On drop of `.txt`,
  `.log`, `.md`, `.csv`, or no extension: open in a new window if
  the current window is dirty or has a file open; otherwise open
  in the current window.

---

## 6. Files & Encoding

### 6.1 Encoding detection (`Files/EncodingDetector.swift`)
- Read first 3 bytes:
  - `EF BB BF` → UTF-8 with BOM.
  - `FF FE` → UTF-16 LE.
  - `FE FF` → UTF-16 BE.
  - Otherwise treat as UTF-8.
- The detected encoding is stored in `DocumentState.encoding` and
  displayed in the status bar.

### 6.2 Line endings (`Files/LineEndingDetector.swift`)
- Count occurrences of `\r\n`, `\r`, `\n` (treating `\r\n` first
  so the `\n` count excludes them). Majority wins; tie defaults to
  CRLF.
- Stored in `DocumentState.lineEnding`. In-memory representation
  is always `\n`; conversion happens on read (normalise to `\n`)
  and on write (re-emit in the chosen ending).

### 6.3 Read / write
- `DocumentReader.read(from:)` throws on I/O error and returns
  `(text, encoding, lineEnding)`. The window controller catches
  and shows an alert — never silent failure.
- `DocumentWriter.write(_:to:encoding:lineEnding:)` writes via
  `Data.write(to:options:.atomic)`.

---

## 7. Testability (the HTTP test API)

### 7.1 Why
Headless verification was the single biggest failure mode of the
prior project. `osascript` synthetic input silently no-ops without
Accessibility permission. `CGEvent` posting requires the same.
The QA harness saw both as "passed".

Slate's contract: every product behavior MUST be reachable via an
HTTP endpoint on `127.0.0.1`. The feature-test check uses only
HTTP. It does not call `osascript`, `CGEvent`, or `AXUIElement`.

### 7.2 Enabling the API
- The server binds when `SLATE_TEST_API=1` is in the launching
  environment. Default off.
- The port is chosen by the OS (bind to `:0`) and written to
  `~/Library/Application Support/Slate/test-api.port` (just the
  decimal number, newline-terminated) before the listener starts
  accepting connections.
- The server runs on a background dispatch queue, but all request
  handlers dispatch to the main queue before touching AppKit
  objects.

### 7.3 Required endpoints

Endpoints are **organised by the controller that owns them**
(see [`.agent/skills/mvc-appkit.md`](./.agent/skills/mvc-appkit.md)).
Every route lives under `/<controller-prefix>/<action>`. The only
top-level exception is `/healthz`, which is registered by
`AppController` for historical reasons.

Every endpoint returns JSON unless noted. Errors return
`{"error":"message"}` with the appropriate 4xx/5xx status.

#### App (`AppController`)

| Method | Path           | Body | Response       | Purpose |
|--------|----------------|------|----------------|---------|
| GET    | `/healthz`     | —    | `{"ok":true}`  | Readiness probe |
| POST   | `/app/shutdown`| —    | `{"ok":true}`  | `NSApp.terminate(nil)` after responding |

#### Window (`WindowController`)

| Method | Path                  | Body / Query                            | Response | Purpose |
|--------|-----------------------|-----------------------------------------|----------|---------|
| GET    | `/window/list`        | —                                       | `[{"id":"w1","title":"Untitled - Notepad","isKey":true}]` | Window inventory |
| GET    | `/window/screenshot`  | query `?windowId=w1` (optional)         | `image/png` bytes | PNG of contentView. In-process only. See §7.6 + §8.13. |

#### Editor (`EditorController`)

| Method | Path           | Body / Query                            | Response | Purpose |
|--------|----------------|-----------------------------------------|----------|---------|
| GET    | `/editor/text` | query `?windowId=w1`                    | `{"text":"hello\n"}` | Read editor contents |
| POST   | `/editor/type` | `{"text":"hello\n","windowId":"w1"}`    | `{"ok":true}` | Insert at current selection (replaces if any). Modifies text storage and posts `NSText.didChangeNotification`. No synthetic key events. |
| GET    | `/editor/state`| query `?windowId=w1`                    | `{"isDirty":true,"encoding":"UTF-8","lineEnding":"CRLF","zoom":100,"selection":{"location":0,"length":0}}` | Editor/document state mirror |

#### Document (`DocumentController`)

| Method | Path                | Body                                                          | Response | Purpose |
|--------|---------------------|---------------------------------------------------------------|----------|---------|
| POST   | `/document/openFile`| `{"path":"/abs/path.txt"}`                                    | `{"ok":true,"windowId":"w2"}` | Open file, bypass NSOpenPanel |
| POST   | `/document/saveAs`  | `{"windowId":"w1","path":"/abs/path.txt","encoding":"UTF-8","lineEnding":"LF"}` | `{"ok":true}` | Save, bypass NSSavePanel |

#### Menu (`MenuController`)

| Method | Path           | Body                          | Response | Purpose |
|--------|----------------|-------------------------------|----------|---------|
| POST   | `/menu/invoke` | `{"path":["File","Open"]}`    | `{"ok":true}` | Invoke a menu item by title path. Walks `NSApp.mainMenu`. Returns 409 on separators or disabled items. |

#### Shortcut (`ShortcutController`)

| Method | Path             | Body                | Response | Purpose |
|--------|------------------|---------------------|----------|---------|
| POST   | `/shortcut/press`| `{"keys":"cmd+s"}`  | `{"ok":true}` | Invoke the same handler closure `KeyboardShortcuts.handleKeyEvent` would; NOT a CGEvent. |

New controllers MAY add new prefixes. New behavior MUST NOT be
added as a top-level route — it must belong to a controller. The
quality-review (PRD §8 + the thermo-nuclear skill) will block PRs
that add top-level routes.

### 7.4 Per-issue contract
Every `slice` issue's body includes an `acceptance:` JSON block
naming HTTP probes. Example for "S2: Editor accepts typed text":

```json
{
  "acceptance": [
    {"step": "type-then-read",
     "calls": [
       {"method":"POST","path":"/type","body":{"text":"hello"}},
       {"method":"GET","path":"/text","expect":{"text":"hello"}}
     ]}
  ]
}
```

The feature-test check fails the issue if any expect-assertion fails.

### 7.5 Security
The listener binds only to `127.0.0.1` and accepts no auth.
`SLATE_TEST_API=1` is opt-in. Release builds shipped to end users
should set this off (it's an env var, not a build flag, so even a
shipped binary stays inert by default).

### 7.6 Self-screenshot

`/screenshot` renders the target window's contentView into a PNG
using **only in-process drawing APIs**. The required path is:

```swift
guard let win = lookupWindow(id) else { /* 404 */ }
let view = win.contentView!
let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
view.cacheDisplay(in: view.bounds, to: rep)
let png = rep.representation(using: .png, properties: [:])!
// respond with Content-Type: image/png
```

It MUST NOT call:

- `CGWindowListCreateImage`
- `CGDisplayCreateImage`
- `NSScreen`-pixel-grab APIs
- shell out to `screencapture`

Any of those require Screen-Recording or Accessibility permission,
which the old `notepad/` project taught us silently degrades to
no-op when not granted. /screenshot must work the moment
`SLATE_TEST_API=1` is set, with zero permission prompts.

---

## 8. Architectural invariants

These rules are extracted from
[`lessons-learned.md`](./lessons-learned.md). The code-quality
check uses this list as its primary review checklist; any
violation blocks the PR.

### 8.1 Entry point
- The app MUST have an explicit `Slate/main.swift` that constructs
  `NSApplication.shared`, assigns the delegate, calls
  `setActivationPolicy(.regular)`, and calls `app.run()`.
- `@main` is forbidden on `NSApplicationDelegate` subclasses.

### 8.2 Text view construction
- Every `NSTextView` MUST be built via the chain
  `NSTextStorage → NSLayoutManager → NSTextContainer → NSTextView`.
- The container size must be `(huge, huge)` initially; word-wrap
  toggling modifies `widthTracksTextView`, not the construction.
- Orphan containers (created with no layout manager attached
  before the text view is built) are a build-blocking review
  failure.

### 8.3 First responder
- `window.makeFirstResponder(...)` MUST receive the inner
  `NSTextView`, not its enclosing `NSScrollView`.

### 8.4 Image loading
- `NSImage(imageLiteralResourceName:)` is forbidden anywhere in
  app code.
- All image loading uses failable `NSImage(named:)` with a
  non-trapping fallback (e.g. `NSImage(named: NSImage.folderName)`
  or a blank `NSImage(size:)`).

### 8.5 Callback re-entrancy
- Any method whose name implies "set X as the current selection /
  current path / current state" MUST update only visual state.
- It MUST NOT emit the user-action callback that the rest of the
  app uses to *request* the same selection. (This is the
  FileBrowserSidebar lesson.)

### 8.6 Borderless windows
- Every `NSWindow` subclass with a `.borderless` style mask MUST
  override `canBecomeKey` and `canBecomeMain` to return `true`.

### 8.7 File panels
- v1 file open / save uses `NSOpenPanel` / `NSSavePanel`. No
  custom file dialog is permitted in v1 (lessons §1.7).

### 8.8 Force-unwrap discipline
- `try!`, `as!`, and `!`-on-optionals are forbidden except in
  these whitelisted cases:
  - `NSScreen.main` access: must use `guard let` + fall back.
  - `URL(string:)` of compile-time string literals known to be valid.
  - `FileManager.default.urls(for:.documentDirectory, in:.userDomainMask).first`:
    must use `guard let`, fall back to `URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")`.

### 8.9 Test API parity
- Every PR that adds a user-visible feature MUST extend
  `TestAPI/TestAPIRoutes.swift` so the feature is reachable
  through HTTP. A PR adding a new menu command without adding the
  ability to invoke it via `/menu` or `/shortcut` fails review.

### 8.10 Silent failure
- `catch { /* ignore */ }` is forbidden. All errors either propagate
  or surface an `NSAlert` on the main queue.

### 8.11 Notifications & observers
- Observers added with
  `NotificationCenter.default.addObserver(forName:object:queue:using:)`
  MUST capture `self` weakly. Strong captures inside closures stored
  by NotificationCenter are PR-blockers.

### 8.12 Synchronous main-queue dispatch from background
- Test API handlers run on a background queue; when they need
  to touch AppKit they use `DispatchQueue.main.sync`. Never call
  AppKit from the background queue directly.

### 8.13 Self-screenshot only
- `/window/screenshot` uses only in-process drawing APIs
  (`NSView.bitmapImageRepForCachingDisplay` →
  `NSView.cacheDisplay(in:to:)` → `NSBitmapImageRep.representation(using:.png)`).
- Any code path that reaches `CGWindowListCreateImage`,
  `CGDisplayCreateImage`, `screencapture`, or any API requiring
  Screen Recording / Accessibility / TCC permission fails review.
- The endpoint MUST work the first time `SLATE_TEST_API=1` is set
  on a freshly installed machine — no permission prompts, no
  silent degradation.

### 8.14 Controller owns its routes (MVC)
- Every user-visible feature lives in an `NSViewController` subclass
  under `Slate/<Feature>/<Name>Controller.swift`.
- That controller MUST register its own HTTP test-API routes by
  conforming to `TestAPIControllerRoutes` and calling
  `TestAPIRouter.shared.register(controller: self)` in `viewDidLoad`.
- Route handlers live in an extension on the controller in the same
  file. They do NOT live under `Slate/App/TestAPI/Routes/*.swift` or
  any other shared route file.
- Views (`NSView` subclasses) MUST NOT reference `TestAPIRouter`,
  `URLSession`, or any HTTP type. Views render the model and forward
  gestures only.
- Models (plain Swift types) MUST NOT `import AppKit`.
- New endpoints MUST be namespaced under their controller's prefix
  (`/<prefix>/<action>`). Top-level routes are forbidden except for
  the legacy `/healthz`.
- The full pattern, including a canonical controller scaffold and the
  required-endpoints table by controller, lives in
  `.agent/skills/mvc-appkit.md`. The code-quality review enforces it
  mechanically.

---

## 9. The orchestrator's contract

(Informational for human readers; not implemented by coding agents.)

- Issues are labelled `slice` and numbered `S1`, `S2`, …
- The first issue (`S1`) is created by `bootstrap` and corresponds
  to "app launches, shows an empty window, `GET /healthz` returns
  200, `GET /windows` returns one entry".
- Subsequent issues are generated by `next-issue` reading PRD §1-§6
  and the list of closed slices. Each new issue must include an
  `acceptance:` block (§7.4) and must extend the test API (§8.9).
- Each issue cycles through:
  `code-agent → xcodebuild → feature-test → quality-review`.
  Failure at any step bumps `attempt:N`. At `N=10`, the
  orchestrator opens a PR with label `awaiting-human-review` and
  closes the issue.

---

## 10. Out of v1, deferred

- Win10-styled file dialogs (replace `NSOpenPanel`).
- Print preview.
- Status-bar (`NSStatusItem`) mode.
- App Store packaging (entitlements, sandboxing, notarisation).
- Multi-language UI.
- A custom app icon.

Each of these becomes a future PRD addendum, never a slice in v1.
