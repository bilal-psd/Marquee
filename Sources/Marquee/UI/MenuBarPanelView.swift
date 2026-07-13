import AppKit
import Combine

final class MenuBarPanelView: NSView {
    private let controller: PlaybackController
    private var cancellables = Set<AnyCancellable>()

    private let prevButton = MenuBarButton()
    private let playButton = MenuBarButton()
    private let nextButton = MenuBarButton()
    private let marquee = MarqueeLabel()
    private let idleLabel = MenuBarIdleLabel(labelWithString: "Nothing playing")

    private let panelHeight = NSStatusBar.system.thickness
    private let maxMarqueeWidth: CGFloat = 160
    private let maxMetadataLength = 200

    private let leadingInset: CGFloat = 4
    private let trailingInset: CGFloat = 6
    private let controlsMarqueeGap: CGFloat = 12
    private let controlsWidth: CGFloat = 18 + 2 + 20 + 2 + 18

    private var marqueeWidthConstraint: NSLayoutConstraint!
    private var playImage: NSImage?
    private var pauseImage: NSImage?
    private var lastIsPlaying: Bool?
    private var lastTextAreaWidth: CGFloat?
    private var isDisplayAwake = true
    private let idleTextWidth: CGFloat

    /// Called when the panel's preferred width changes (e.g. track title length).
    var onWidthChange: (() -> Void)?

    /// Right-click menu (About, GitHub, Quit) — set by AppDelegate.
    var contextMenu: NSMenu?

    init(controller: PlaybackController) {
        self.controller = controller
        let idleFont = NSFont.systemFont(ofSize: 11)
        idleTextWidth = ceil(
            ("Nothing playing" as NSString).size(withAttributes: [.font: idleFont]).width
        ) + 1
        super.init(frame: NSRect(x: 0, y: 0, width: 175, height: NSStatusBar.system.thickness))
        setup()
        observe()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: panelWidth(textArea: currentTextAreaWidth()), height: panelHeight)
    }

    /// Called by the app delegate on display sleep/wake to pause the marquee.
    func setDisplayAwake(_ awake: Bool) {
        guard isDisplayAwake != awake else { return }
        isDisplayAwake = awake
        updateMarqueeActive()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenu
    }

    private func setup() {
        playImage = templateSymbol("play.fill", pointSize: 11)
        pauseImage = templateSymbol("pause.fill", pointSize: 11)

        configure(button: prevButton, image: templateSymbol("backward.fill", pointSize: 9), action: #selector(previous))
        configure(button: playButton, image: playImage, action: #selector(playPause))
        configure(button: nextButton, image: templateSymbol("forward.fill", pointSize: 9), action: #selector(next))

        idleLabel.font = .systemFont(ofSize: 11)
        idleLabel.textColor = .secondaryLabelColor

        marquee.maxWidth = maxMarqueeWidth
        marquee.fontSize = 11

        [prevButton, playButton, nextButton, marquee, idleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        marqueeWidthConstraint = marquee.widthAnchor.constraint(equalToConstant: maxMarqueeWidth)

        NSLayoutConstraint.activate([
            prevButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 18),
            prevButton.heightAnchor.constraint(equalToConstant: 18),

            playButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 2),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 20),
            playButton.heightAnchor.constraint(equalToConstant: 20),

            nextButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 2),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 18),
            nextButton.heightAnchor.constraint(equalToConstant: 18),

            marquee.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: controlsMarqueeGap),
            marquee.centerYAnchor.constraint(equalTo: centerYAnchor),
            marqueeWidthConstraint,
            marquee.heightAnchor.constraint(equalToConstant: 15),

            idleLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: controlsMarqueeGap),
            idleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            idleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -trailingInset),
        ])
    }

    private func panelWidth(textArea: CGFloat) -> CGFloat {
        leadingInset + controlsWidth + controlsMarqueeGap + textArea + trailingInset
    }

    private func currentTextAreaWidth() -> CGFloat {
        if controller.nowPlaying != nil {
            return marquee.displayWidth
        }
        return idleTextWidth
    }

    private func updateTextAreaWidth() {
        let width = currentTextAreaWidth()
        guard lastTextAreaWidth == nil || abs(lastTextAreaWidth! - width) > 0.5 else { return }
        lastTextAreaWidth = width
        marqueeWidthConstraint.constant = width
        invalidateIntrinsicContentSize()
        onWidthChange?()
    }

    private func templateSymbol(_ name: String, pointSize: CGFloat) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private func configure(button: MenuBarButton, image: NSImage?, action: Selector) {
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.imagePosition = .imageOnly
        button.image = image
    }

    private func observe() {
        controller.$nowPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let nowPlaying = controller.nowPlaying else {
            setPlaySymbol(isPlaying: false)
            marquee.isHidden = true
            idleLabel.isHidden = false
            setControlsEnabled(false)
            updateMarqueeActive()
            updateTextAreaWidth()
            return
        }

        setPlaySymbol(isPlaying: nowPlaying.isPlaying)
        let title = clamp(nowPlaying.title)
        let artist = clamp(nowPlaying.artist)
        marquee.text = "\(title) — \(artist)"
        marquee.toolTip = "\(title) by \(artist) · \(nowPlaying.sourceName)"
        marquee.isHidden = false
        idleLabel.isHidden = true
        setControlsEnabled(true)
        updateMarqueeActive()
        updateTextAreaWidth()
    }

    private func updateMarqueeActive() {
        let playing = controller.nowPlaying?.isPlaying == true
        marquee.isActive = playing && isDisplayAwake && !marquee.isHidden
    }

    private func clamp(_ string: String) -> String {
        guard string.count > maxMetadataLength else { return string }
        return String(string.prefix(maxMetadataLength)) + "…"
    }

    private func setPlaySymbol(isPlaying: Bool) {
        guard lastIsPlaying != isPlaying else { return }
        lastIsPlaying = isPlaying
        playButton.image = isPlaying ? pauseImage : playImage
    }

    private func setControlsEnabled(_ enabled: Bool) {
        prevButton.isEnabled = enabled
        playButton.isEnabled = enabled
        nextButton.isEnabled = enabled
    }

    @objc private func playPause() {
        controller.playPause()
    }

    @objc private func previous() {
        controller.previousTrack()
    }

    @objc private func next() {
        controller.nextTrack()
    }
}
