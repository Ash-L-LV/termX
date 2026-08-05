import AppKit

/// Builds the small clickable repository link shown in the About dialog.
enum AboutView {
    static let repoURL = URL(string: "https://github.com/Ash-L-LV/termX")!

    /// Returns a fixed-size container holding `text` as a tappable hyperlink.
    static func makeLinkField(text: String) -> NSView {
        let label = NSTextField(labelWithString: "")
        label.isSelectable = true
        label.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .link: repoURL,
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
        )
        label.sizeToFit()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: label.frame.width, height: label.frame.height))
        label.frame.origin = .zero
        container.addSubview(label)
        return container
    }
}
