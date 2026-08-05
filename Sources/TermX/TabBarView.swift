import AppKit
import TermXCore

/// A single tab in the custom tab strip.
final class TabItemView: NSView {
    private let closeButton = NSButton()
    private var dragStart: NSPoint?

    var title: String {
        didSet { needsDisplay = true }
    }
    var subtitle: String? {
        didSet { needsDisplay = true }
    }
    var tabColor: NSColor? {
        didSet { needsDisplay = true }
    }
    var isActive = false { didSet { needsDisplay = true } }
    var isDead = false { didSet { needsDisplay = true } }

    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onDetach: (() -> Void)?

    var desiredWidth: CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        var textWidth = (title as NSString).size(withAttributes: attributes).width
        if let subtitle, !subtitle.isEmpty {
            let subAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10)]
            textWidth = max(textWidth, (subtitle as NSString).size(withAttributes: subAttributes).width)
        }
        return min(260, max(120, textWidth + 62))
    }

    init(title: String, subtitle: String? = nil, tabColor: NSColor? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.tabColor = tabColor
        super.init(frame: .zero)

        closeButton.title = "✕"
        closeButton.font = .systemFont(ofSize: 9, weight: .semibold)
        closeButton.isBordered = false
        closeButton.bezelStyle = .inline
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.toolTip = L.t("closeTabTip")
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let closeSize: CGFloat = 18
        closeButton.frame = NSRect(x: bounds.maxX - closeSize - 6, y: (bounds.height - closeSize) / 2, width: closeSize, height: closeSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        let accent = tabColor ?? NSColor.controlAccentColor
        if isActive {
            accent.withAlphaComponent(tabColor == nil ? 0.24 : 0.45).setFill()
            path.fill()
            let line = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            line.lineWidth = 1
            accent.withAlphaComponent(tabColor == nil ? 0.5 : 0.8).setStroke()
            line.stroke()
        } else if let tabColor, !isDead {
            tabColor.withAlphaComponent(0.28).setFill()
            path.fill()
            let line = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            line.lineWidth = 1
            tabColor.withAlphaComponent(0.45).setStroke()
            line.stroke()
        } else {
            NSColor.clear.setFill()
            path.fill()
        }

        let textX: CGFloat = 12

        let textColor: NSColor
        if isDead {
            textColor = .tertiaryLabelColor
        } else if tabColor != nil || isActive {
            textColor = .labelColor
        } else {
            textColor = .secondaryLabelColor
        }
        let textWidth = max(0, bounds.width - 56)

        if let subtitle, !subtitle.isEmpty {
            let primaryAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: textColor,
            ]
            let primaryRect = NSRect(x: textX, y: 5, width: textWidth, height: 16)
            NSAttributedString(string: title, attributes: primaryAttributes)
                .draw(with: primaryRect,
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                      context: nil)

            let secondaryAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.8),
            ]
            let secondaryRect = NSRect(x: textX, y: 23, width: textWidth, height: 14)
            NSAttributedString(string: subtitle, attributes: secondaryAttributes)
                .draw(with: secondaryRect,
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                      context: nil)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: textColor,
            ]
            let textRect = NSRect(x: textX, y: (bounds.height - 16) / 2, width: textWidth, height: 16)
            NSAttributedString(string: title, attributes: attributes)
                .draw(with: textRect,
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                      context: nil)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        if hypot(point.x - start.x, point.y - start.y) > 10 {
            dragStart = nil
            onDetach?()
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let start = dragStart, hypot(point.x - start.x, point.y - start.y) <= 10 {
            onSelect?()
        }
        dragStart = nil
    }

    @objc private func closeTapped() {
        onClose?()
    }

}

/// The horizontal tab strip shown above the terminal content.
final class TabStripView: NSView {
    /// Visual feedback while a detached window is being dragged over the
    /// strip as a drop target.
    var isDropTarget = false {
        didSet { needsDisplay = true }
    }

    var items: [TabItemView] = [] {
        didSet {
            for subview in subviews where subview is TabItemView {
                subview.removeFromSuperview()
            }
            for item in items {
                addSubview(item)
            }
            needsLayout = true
        }
    }
    var plusAction: ((NSView) -> Void)?

    private let plusButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        plusButton.title = "＋"
        plusButton.font = .systemFont(ofSize: 14, weight: .medium)
        plusButton.isBordered = false
        plusButton.bezelStyle = .inline
        plusButton.contentTintColor = .secondaryLabelColor
        plusButton.target = self
        plusButton.action = #selector(plusTapped)
        plusButton.toolTip = L.t("plusTip")
        addSubview(plusButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 6
        for item in items {
            let width = item.desiredWidth
            item.frame = NSRect(x: x, y: 3, width: width, height: bounds.height - 6)
            x += width + 4
        }
        plusButton.frame = NSRect(x: x + 2, y: 3, width: 26, height: bounds.height - 6)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        if isDropTarget {
            let highlight = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2),
                                         xRadius: 6, yRadius: 6)
            NSColor.controlAccentColor.withAlphaComponent(0.30).setFill()
            highlight.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
            highlight.lineWidth = 2
            highlight.stroke()
        }
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    @objc private func plusTapped() {
        plusAction?(plusButton)
    }
}
