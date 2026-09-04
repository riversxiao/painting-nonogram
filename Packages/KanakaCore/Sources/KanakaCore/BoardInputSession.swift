public enum BoardStrokeAxis: String, Equatable, Sendable {
    case undecided
    case horizontal
    case vertical
}

/// Builds one atomic edit transaction from a tap or axis-locked drag.
public struct BoardInputSession: Sendable {
    public let axisLockThreshold: Double
    public private(set) var axis: BoardStrokeAxis = .undecided
    public private(set) var previewCoordinates: [CellCoordinate] = []

    private var activeStroke: ActiveStroke?

    public init(axisLockThreshold: Double = 10) {
        self.axisLockThreshold = max(0, axisLockThreshold.isFinite ? axisLockThreshold : 10)
    }

    public var isActive: Bool { activeStroke != nil }

    @discardableResult
    public mutating func begin(
        at point: BoardPoint,
        targetState: CellState,
        geometry: BoardGeometry,
        blockedCoordinates: Set<CellCoordinate> = []
    ) -> Bool {
        guard activeStroke == nil,
              let coordinate = geometry.coordinate(at: point),
              !blockedCoordinates.contains(coordinate) else {
            return false
        }
        activeStroke = ActiveStroke(
            startPoint: point,
            startCoordinate: coordinate,
            targetState: targetState,
            blockedCoordinates: blockedCoordinates
        )
        axis = .undecided
        previewCoordinates = [coordinate]
        return true
    }

    @discardableResult
    public mutating func move(to point: BoardPoint, geometry: BoardGeometry) -> [CellCoordinate] {
        guard point.x.isFinite, point.y.isFinite,
              let stroke = activeStroke else { return previewCoordinates }
        if axis == .undecided {
            let dx = point.x - stroke.startPoint.x
            let dy = point.y - stroke.startPoint.y
            guard dx * dx + dy * dy >= axisLockThreshold * axisLockThreshold else {
                return previewCoordinates
            }
            axis = abs(dx) >= abs(dy) ? .horizontal : .vertical
        }

        let nearest = geometry.nearestCoordinate(to: point)
        let destination: CellCoordinate
        switch axis {
        case .undecided:
            destination = stroke.startCoordinate
        case .horizontal:
            destination = CellCoordinate(x: nearest.x, y: stroke.startCoordinate.y)
        case .vertical:
            destination = CellCoordinate(x: stroke.startCoordinate.x, y: nearest.y)
        }
        previewCoordinates = Self.coordinates(
            from: stroke.startCoordinate,
            through: destination,
            axis: axis
        ).filter { !stroke.blockedCoordinates.contains($0) }
        return previewCoordinates
    }

    public mutating func end() -> [CellEdit] {
        guard let stroke = activeStroke else { return [] }
        let edits = previewCoordinates.map {
            CellEdit(coordinate: $0, state: stroke.targetState)
        }
        clear()
        return edits
    }

    public mutating func cancel() {
        clear()
    }

    /// A second touch changes intent to viewport manipulation, so no cell edit may be committed.
    public mutating func secondaryTouchBegan() {
        cancel()
    }

    private mutating func clear() {
        activeStroke = nil
        axis = .undecided
        previewCoordinates = []
    }

    private static func coordinates(
        from start: CellCoordinate,
        through end: CellCoordinate,
        axis: BoardStrokeAxis
    ) -> [CellCoordinate] {
        switch axis {
        case .undecided:
            return [start]
        case .horizontal:
            let step = end.x >= start.x ? 1 : -1
            return stride(from: start.x, through: end.x, by: step).map {
                CellCoordinate(x: $0, y: start.y)
            }
        case .vertical:
            let step = end.y >= start.y ? 1 : -1
            return stride(from: start.y, through: end.y, by: step).map {
                CellCoordinate(x: start.x, y: $0)
            }
        }
    }
}

private struct ActiveStroke: Sendable {
    let startPoint: BoardPoint
    let startCoordinate: CellCoordinate
    let targetState: CellState
    let blockedCoordinates: Set<CellCoordinate>
}
