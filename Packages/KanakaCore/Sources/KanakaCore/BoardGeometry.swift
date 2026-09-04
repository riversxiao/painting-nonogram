public struct BoardPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct BoardSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct BoardInsets: Equatable, Sendable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

public struct BoardRect: Equatable, Sendable {
    public var origin: BoardPoint
    public var size: BoardSize

    public init(origin: BoardPoint, size: BoardSize) {
        self.origin = origin
        self.size = size
    }

    /// Uses half-open bounds so a point on the right or bottom edge never aliases another cell.
    public func contains(_ point: BoardPoint) -> Bool {
        point.x >= origin.x && point.y >= origin.y
            && point.x < origin.x + size.width
            && point.y < origin.y + size.height
    }
}

public enum BoardGeometryError: Error, Equatable, CustomStringConvertible {
    case invalidDimensions
    case invalidCellSize
    case invalidViewport
    case invalidInsets
    case invalidScaleRange

    public var description: String {
        switch self {
        case .invalidDimensions: return "Board dimensions must be between 1 and the core maximum"
        case .invalidCellSize: return "Board cell size must be finite and positive"
        case .invalidViewport: return "Board viewport must be finite and positive"
        case .invalidInsets: return "Board insets must be finite and nonnegative"
        case .invalidScaleRange: return "Board scale range must be finite, positive, and ordered"
        }
    }
}

/// Platform-independent mapping between top-left logical cells and viewport points.
public struct BoardGeometry: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let cellSize: Double
    public let insets: BoardInsets
    public let minimumScale: Double
    public let maximumScale: Double
    public private(set) var viewportSize: BoardSize
    public private(set) var scale: Double
    public private(set) var translation: BoardPoint

    public init(
        columns: Int,
        rows: Int,
        cellSize: Double = 36,
        insets: BoardInsets = BoardInsets(),
        viewportSize: BoardSize,
        minimumScale: Double = 0.25,
        maximumScale: Double = 4
    ) throws {
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(columns),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(rows) else {
            throw BoardGeometryError.invalidDimensions
        }
        guard cellSize.isFinite, cellSize > 0 else { throw BoardGeometryError.invalidCellSize }
        guard viewportSize.width.isFinite, viewportSize.width > 0,
              viewportSize.height.isFinite, viewportSize.height > 0 else {
            throw BoardGeometryError.invalidViewport
        }
        let insetValues = [insets.top, insets.leading, insets.bottom, insets.trailing]
        guard insetValues.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw BoardGeometryError.invalidInsets
        }
        guard minimumScale.isFinite, maximumScale.isFinite,
              minimumScale > 0, maximumScale >= minimumScale else {
            throw BoardGeometryError.invalidScaleRange
        }

        self.columns = columns
        self.rows = rows
        self.cellSize = cellSize
        self.insets = insets
        self.viewportSize = viewportSize
        self.minimumScale = minimumScale
        self.maximumScale = maximumScale
        scale = minimumScale
        translation = BoardPoint(x: 0, y: 0)
        resetToFit()
    }

    public var unscaledContentSize: BoardSize {
        BoardSize(
            width: insets.leading + Double(columns) * cellSize + insets.trailing,
            height: insets.top + Double(rows) * cellSize + insets.bottom
        )
    }

    public var contentSize: BoardSize {
        BoardSize(
            width: unscaledContentSize.width * scale,
            height: unscaledContentSize.height * scale
        )
    }

    public var boardRect: BoardRect {
        BoardRect(
            origin: BoardPoint(
                x: translation.x + insets.leading * scale,
                y: translation.y + insets.top * scale
            ),
            size: BoardSize(
                width: Double(columns) * cellSize * scale,
                height: Double(rows) * cellSize * scale
            )
        )
    }

    public func cellRect(at coordinate: CellCoordinate) -> BoardRect? {
        guard contains(coordinate) else { return nil }
        let board = boardRect
        return BoardRect(
            origin: BoardPoint(
                x: board.origin.x + Double(coordinate.x) * cellSize * scale,
                y: board.origin.y + Double(coordinate.y) * cellSize * scale
            ),
            size: BoardSize(width: cellSize * scale, height: cellSize * scale)
        )
    }

    public func coordinate(at point: BoardPoint) -> CellCoordinate? {
        let board = boardRect
        guard point.x.isFinite, point.y.isFinite, board.contains(point) else { return nil }
        return CellCoordinate(
            x: Int((point.x - board.origin.x) / (cellSize * scale)),
            y: Int((point.y - board.origin.y) / (cellSize * scale))
        )
    }

    public func nearestCoordinate(to point: BoardPoint) -> CellCoordinate {
        guard point.x.isFinite, point.y.isFinite else {
            return CellCoordinate(x: 0, y: 0)
        }
        let board = boardRect
        let x = Int(((point.x - board.origin.x) / (cellSize * scale)).rounded(.down))
        let y = Int(((point.y - board.origin.y) / (cellSize * scale)).rounded(.down))
        return CellCoordinate(
            x: min(max(x, 0), columns - 1),
            y: min(max(y, 0), rows - 1)
        )
    }

    public func viewportPoint(forUnscaledContentPoint point: BoardPoint) -> BoardPoint {
        BoardPoint(
            x: translation.x + point.x * scale,
            y: translation.y + point.y * scale
        )
    }

    public func unscaledContentPoint(forViewportPoint point: BoardPoint) -> BoardPoint {
        BoardPoint(
            x: (point.x - translation.x) / scale,
            y: (point.y - translation.y) / scale
        )
    }

    public mutating func resetToFit() {
        let content = unscaledContentSize
        let fitScale = min(viewportSize.width / content.width, viewportSize.height / content.height)
        scale = min(max(min(1, fitScale), minimumScale), maximumScale)
        translation = clampedTranslation(BoardPoint(x: 0, y: 0), at: scale)
    }

    public mutating func resizeViewport(to size: BoardSize) throws {
        guard size.width.isFinite, size.width > 0, size.height.isFinite, size.height > 0 else {
            throw BoardGeometryError.invalidViewport
        }
        let oldCenter = BoardPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let logicalCenter = unscaledContentPoint(forViewportPoint: oldCenter)
        viewportSize = size
        let newCenter = BoardPoint(x: size.width / 2, y: size.height / 2)
        translation = clampedTranslation(
            BoardPoint(
                x: newCenter.x - logicalCenter.x * scale,
                y: newCenter.y - logicalCenter.y * scale
            ),
            at: scale
        )
    }

    public mutating func setScale(_ requestedScale: Double, anchoredAt anchor: BoardPoint) {
        guard requestedScale.isFinite, anchor.x.isFinite, anchor.y.isFinite else { return }
        let logicalAnchor = unscaledContentPoint(forViewportPoint: anchor)
        let nextScale = min(max(requestedScale, minimumScale), maximumScale)
        scale = nextScale
        translation = clampedTranslation(
            BoardPoint(
                x: anchor.x - logicalAnchor.x * nextScale,
                y: anchor.y - logicalAnchor.y * nextScale
            ),
            at: nextScale
        )
    }

    public mutating func pan(by delta: BoardPoint) {
        guard delta.x.isFinite, delta.y.isFinite else { return }
        translation = clampedTranslation(
            BoardPoint(x: translation.x + delta.x, y: translation.y + delta.y),
            at: scale
        )
    }

    private func contains(_ coordinate: CellCoordinate) -> Bool {
        (0..<columns).contains(coordinate.x) && (0..<rows).contains(coordinate.y)
    }

    private func clampedTranslation(_ proposed: BoardPoint, at scale: Double) -> BoardPoint {
        let content = BoardSize(
            width: unscaledContentSize.width * scale,
            height: unscaledContentSize.height * scale
        )
        return BoardPoint(
            x: Self.clampedAxis(proposed.x, content: content.width, viewport: viewportSize.width),
            y: Self.clampedAxis(proposed.y, content: content.height, viewport: viewportSize.height)
        )
    }

    private static func clampedAxis(_ proposed: Double, content: Double, viewport: Double) -> Double {
        if content <= viewport { return (viewport - content) / 2 }
        return min(0, max(viewport - content, proposed))
    }
}
