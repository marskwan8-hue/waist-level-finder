import CoreGraphics

/// Where everything goes on screen.
///
/// - **Waist level**: the iPhone Duo is half folded with the fold horizontal, like a small
///   laptop. The upright half is the hood (info and settings), and the half lying flat is the
///   focusing screen you look down on, with the controls beside it.
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
    let counter: CGPoint
    /// Whether the tool buttons stack vertically (beside the screen) or sit in a row (below it).
    let toolsAreVertical: Bool

    private static let controlColumn: CGFloat = 112
    private static let margin: CGFloat = 16

    init(size: CGSize, fold: CGRect?) {
        if let fold, fold.width > fold.height {
            self.init(waistLevelIn: size, fold: fold)
        } else {
            self.init(handheldIn: size, isBookPose: fold != nil)
        }
    }

    private init(waistLevelIn size: CGSize, fold: CGRect) {
        let deck = CGRect(x: 0, y: fold.maxY, width: size.width, height: max(size.height - fold.maxY, 0))
        let side = max(min(deck.height - 2 * Self.margin, size.width - 2 * Self.controlColumn), 0)
        let glass = CGRect(x: deck.midX - side / 2, y: deck.midY - side / 2, width: side, height: side)
        let leftX = glass.minX / 2
        let rightX = (glass.maxX + size.width) / 2

        mode = .waistLevel
        hood = CGRect(x: 0, y: 0, width: size.width, height: max(fold.minY, 0))
        self.glass = glass
        tools = CGPoint(x: leftX, y: deck.midY)
        shutter = CGPoint(x: rightX, y: deck.midY + side * 0.12)
        counter = CGPoint(x: rightX, y: deck.midY - side * 0.28)
        toolsAreVertical = true
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
            shutter = CGPoint(x: rightX, y: glass.midY + side * 0.12)
            counter = CGPoint(x: rightX, y: glass.midY - side * 0.28)
            toolsAreVertical = true
        } else {
            let controlsHeight: CGFloat = 150
            let side = max(min(size.width - 2 * Self.margin, size.height - controlsHeight - 2 * Self.margin), 0)
            let top = (size.height - controlsHeight - side) / 2
            let glass = CGRect(x: (size.width - side) / 2, y: top, width: side, height: side)
            let controlsY = glass.maxY + (size.height - glass.maxY) / 2
            self.glass = glass
            tools = CGPoint(x: size.width * 0.2, y: controlsY)
            shutter = CGPoint(x: size.width * 0.5, y: controlsY)
            counter = CGPoint(x: size.width * 0.8, y: controlsY)
            toolsAreVertical = false
        }
    }
}
