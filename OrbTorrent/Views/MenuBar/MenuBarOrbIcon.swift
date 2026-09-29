import AppKit

/// The menu bar icon: a small orb whose light fills up as downloads progress,
/// and rests full when nothing is downloading.
///
/// It's a template image, so it takes the menu bar's own colour. It doesn't
/// animate or change width; it's redrawn when the progress moves.
@MainActor
enum MenuBarOrbIcon {
    private static var cache: [Int: NSImage] = [:]
    /// Enough steps for the surface to move about a pixel at a time.
    private static let steps = 40

    static func image(for state: OrbState) -> NSImage {
        if case .downloading(let progress, _) = state {
            // A sliver of light even at the start, so a new download shows.
            return image(step: Int((min(max(progress, 0.1), 1) * Double(steps)).rounded(.down)))
        }
        return image(step: steps)
    }

    private static func image(step: Int) -> NSImage {
        if let image = cache[step] { return image }
        let ink = AppIdentity.isDevelopment ? NSColor.systemOrange : .black
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            // The glass.
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.65, dy: 1.65))
            ring.lineWidth = 1.3
            ink.setStroke()
            ring.stroke()

            // The light inside, filled from the bottom, with a gentle wave on its surface.
            let inner = rect.insetBy(dx: 4.2, dy: 4.2)
            let fill = Double(step) / Double(steps)
            let surface = inner.minY + inner.height * fill
            let amplitude = fill < 1 ? 0.6 : 0
            let light = NSBezierPath()
            light.move(to: NSPoint(x: inner.minX, y: inner.minY))
            for i in 0...16 {
                let u = Double(i) / 16
                let wave = sin(u * .pi * 1.9 + 0.8) * 0.65 + sin(u * .pi * 3.7 - 0.4) * 0.35
                light.line(to: NSPoint(x: inner.minX + inner.width * u, y: surface + amplitude * wave))
            }
            light.line(to: NSPoint(x: inner.maxX, y: inner.minY))
            light.close()

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: inner).addClip()
            ink.setFill()
            light.fill()
            // A glint at the top left, so a full orb reads as a sphere.
            if fill >= 1 {
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                NSColor.black.withAlphaComponent(0.75).setFill()
                NSBezierPath(ovalIn: NSRect(x: inner.minX + 2.1, y: inner.maxY - 4.3, width: 2.9, height: 2.1)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        // OrbTorrent Dev's is amber, to tell the two apart in the menu bar.
        image.isTemplate = !AppIdentity.isDevelopment
        image.accessibilityDescription = AppIdentity.name
        cache[step] = image
        return image
    }
}
