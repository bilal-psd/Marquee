import AppKit
import QuartzCore

/// A menu-bar label that scrolls overflowing text as a seamless, continuous
/// ticker.
///
/// Two identical text copies are laid out one after the other separated by
/// `gap`. Both are moved left together each frame; once the pair has advanced a
/// full period (`textWidth + gap`), the offset wraps by exactly that amount.
/// Because the second copy sits precisely one period ahead, the wrap is
/// invisible, producing an endless loop that shows the whole title.
///
/// The scroll timer only runs while `isActive` is true (playing), the view is
/// on-screen, and the text actually overflows — so it costs nothing while
/// paused, hidden, or the display is asleep.
final class MarqueeLabel: NSView {
    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            rebuild()
        }
    }

    var maxWidth: CGFloat = 180 {
        didSet { needsLayout = true }
    }

    /// Width the parent should allocate: full text when it fits, capped at
    /// `maxWidth` when scrolling is needed.
    var displayWidth: CGFloat {
        min(textWidth, maxWidth)
    }

    var fontSize: CGFloat = 12 {
        didSet {
            let font = NSFont.systemFont(ofSize: fontSize)
            copyA.font = font
            copyB.font = font
            rebuild()
        }
    }

    /// When false, scrolling is stopped (used to save energy while paused,
    /// hidden, or the display is asleep).
    var isActive: Bool = true {
        didSet {
            guard isActive != oldValue else { return }
            updateTimerState()
        }
    }

    private let copyA = NSTextField(labelWithString: "")
    private let copyB = NSTextField(labelWithString: "")
    private let gap: CGFloat = 44
    private let speed: CGFloat = 18 // points per second

    private var textWidth: CGFloat = 0
    private var offset: CGFloat = 0
    private var scrollTimer: Timer?
    private var lastTick: TimeInterval = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        scrollTimer?.invalidate()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        for copy in [copyA, copyB] {
            copy.isEditable = false
            copy.isBordered = false
            copy.drawsBackground = false
            copy.font = .systemFont(ofSize: fontSize)
            copy.textColor = .labelColor
            copy.lineBreakMode = .byClipping
            copy.maximumNumberOfLines = 1
            addSubview(copy)
        }
    }

    private var font: NSFont { .systemFont(ofSize: fontSize) }
    private var period: CGFloat { textWidth + gap }
    private var needsScroll: Bool { textWidth > bounds.width + 0.5 }

    /// Measure the full rendered width directly; `sizeToFit` can be clipped by
    /// the surrounding layout, which caused only part of the title to scroll.
    private func measuredWidth(_ string: String) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: font]).width) + 1
    }

    private func rebuild() {
        copyA.stringValue = text
        copyB.stringValue = text
        textWidth = measuredWidth(text)
        offset = 0
        positionCopies()
        updateTimerState()
    }

    override func layout() {
        super.layout()
        positionCopies()
        updateTimerState()
    }

    private func positionCopies() {
        let textHeight = ceil(font.ascender - font.descender)
        let y = (bounds.height - textHeight) / 2

        if needsScroll {
            copyB.isHidden = false
            copyA.frame = NSRect(x: offset, y: y, width: textWidth, height: textHeight)
            copyB.frame = NSRect(x: offset + period, y: y, width: textWidth, height: textHeight)
        } else {
            copyB.isHidden = true
            offset = 0
            copyA.frame = NSRect(x: 0, y: y, width: textWidth, height: textHeight)
        }
    }

    private func updateTimerState() {
        let shouldScroll = isActive && needsScroll && window != nil && !isHiddenOrHasHiddenAncestor
        if shouldScroll {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func startTimer() {
        guard scrollTimer == nil else { return }
        lastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }

    private func stopTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func step() {
        let now = CACurrentMediaTime()
        let delta = CGFloat(now - lastTick)
        lastTick = now

        offset -= speed * delta
        if offset <= -period {
            offset += period
        }
        positionCopies()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTimerState()
    }
}
