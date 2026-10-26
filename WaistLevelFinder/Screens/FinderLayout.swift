import CoreGraphics

/// Where everything goes on screen.
///
/// - **Waist level**: the iPhone Duo is half folded with the fold horizontal, like a small
///   laptop. The half lying flat is the focusing screen you look down on, with the shutter
///   beside it; the upright half is the hood, with the other controls and settings.
/// - **Handheld**: flat, closed or held like a book. A plain square viewfinder.
///
/// Everything is computed in one place so the camera preview keeps its identity, and its
/// capture connection, when the layout changes.
struct FinderLayout {
    enum Mode: Equatable {
        case waistLevel
        case handheld(isBookPose: Bool)
    }

    let mode: Mode
    /// The upright half above the fold, in waist-level mode.
    let hood: CGRect?
    let glass: CGRect
    let tools: CGPoint
    let shutter: CGPoint
    /// The settings button, in handheld mode. In waist-level mode it's on the hood.
    let settings: CGPoint?

    private static let controlColumn: CGFloat = 150
    private static let shutterColumn: CGFloat = 120
    private static let margin: CGFloat = 16

    init(size: CGSize, fold: CGRect?) {
        if let fold, fold.width > fold.height {
            self.init(waistLevelIn: size, fold: fold)
        } else {
            self.init(handheldIn: size, isBookPose: fold != nil)
        }
    }

    private init(waistLevelIn size: CGSize, fold: CGRect) {
        // The flat half holds only the focusing screen, as big as it fits, and the shutter
        // beside it. Everything else sits on the upright half.
        let hood = CGRect(x: 0, y: 0, width: size.width, height: max(fold.minY, 0))
        let deck = CGRect(x: 0, y: fold.maxY, width: size.width, height: max(size.height - fold.maxY, 0))
        let side = max(min(deck.height - 2 * Self.margin, size.width - 2 * Self.shutterColumn), 0)
        let glass = CGRect(x: deck.midX - side / 2, y: deck.midY - side / 2, width: side, height: side)

        mode = .waistLevel
        self.hood = hood
        self.glass = glass
        shutter = CGPoint(x: (glass.maxX + size.width) / 2, y: deck.midY)
        tools = CGPoint(x: hood.midX, y: hood.midY + 12)
        settings = nil
    }

    private init(handheldIn size: CGSize, isBookPose: Bool) {
        mode = .handheld(isBookPose: isBookPose)
        hood = nil

        if size.width > size.height {
            let side = max(min(size.height - 2 * Self.margin, size.width - 2 * Self.controlColumn), 0)
            let glass = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            let rightX = (glass.maxX + size.width) / 2
            self.glass = glass
            tools = CGPoint(x: glass.minX / 2, y: glass.midY)
            shutter = CGPoint(x: rightX, y: glass.midY)
            settings = CGPoint(x: size.width - 36, y: 32)
        } else {
            let controlsHeight: CGFloat = 170
            let side = max(min(size.width - 2 * Self.margin, size.height - controlsHeight - 2 * Self.margin), 0)
            let top = (size.height - controlsHeight - side) / 2
            let glass = CGRect(x: (size.width - side) / 2, y: top, width: side, height: side)
            let controlsY = glass.maxY + (size.height - glass.maxY) / 2
            self.glass = glass
            tools = CGPoint(x: size.width * 0.28, y: controlsY)
            shutter = CGPoint(x: size.width * 0.72, y: controlsY)
            settings = CGPoint(x: size.width - 36, y: 32)
        }
    }
}
