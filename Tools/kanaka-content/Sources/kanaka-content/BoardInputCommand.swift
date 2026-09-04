import Foundation
import KanakaContentKit
import KanakaCore

func validateBoardInput(puzzleURL: URL) throws {
    let puzzle = try JSONDecoder().decode(
        PuzzleDefinition.self,
        from: Data(contentsOf: puzzleURL)
    )
    _ = try PuzzleContentValidator.validate(puzzle)

    try validateGeometryMatrix()
    try validateViewportTransform()
    let horizontalEdits = try validateStrokeTransactions(puzzle: puzzle)
    try validateGameSessionBoundary(puzzle: puzzle, edits: horizontalEdits)

    print([
        "✓ Board geometry and input validation",
        "  geometry matrix: 1×1, 5×5, 20×25, 25×25",
        "  coordinates: top-left round trip and half-open edges passed",
        "  viewport: anchored zoom and deterministic pan clamp passed",
        "  input: tap, threshold, axis lock, interpolation, blocked cells, cancellation passed",
        "  transaction: frozen state, one drag/Undo/Redo, no-op and atomic rejection passed",
    ].joined(separator: "\n"))
}

private func validateGeometryMatrix() throws {
    let cases: [(Int, Int, BoardSize)] = [
        (1, 1, BoardSize(width: 180, height: 140)),
        (5, 5, BoardSize(width: 320, height: 480)),
        (20, 25, BoardSize(width: 390, height: 844)),
        (25, 25, BoardSize(width: 1_024, height: 768)),
    ]
    for (columns, rows, viewport) in cases {
        let geometry = try BoardGeometry(
            columns: columns,
            rows: rows,
            cellSize: 36,
            insets: BoardInsets(top: 96, leading: 128, bottom: 8, trailing: 8),
            viewportSize: viewport
        )
        for y in 0..<rows {
            for x in 0..<columns {
                let coordinate = CellCoordinate(x: x, y: y)
                guard let rect = geometry.cellRect(at: coordinate) else {
                    throw boardFailure("missing rect for \(columns)×\(rows) cell (\(x), \(y))")
                }
                let center = BoardPoint(
                    x: rect.origin.x + rect.size.width / 2,
                    y: rect.origin.y + rect.size.height / 2
                )
                try require(
                    geometry.coordinate(at: center) == coordinate,
                    "cell center did not round-trip for \(columns)×\(rows) cell (\(x), \(y))"
                )
                if x + 1 < columns, let next = geometry.cellRect(
                    at: CellCoordinate(x: x + 1, y: y)
                ) {
                    try require(
                        approximatelyEqual(rect.origin.x + rect.size.width, next.origin.x),
                        "horizontal cell rects overlap or leave a gap"
                    )
                }
                if y + 1 < rows, let next = geometry.cellRect(
                    at: CellCoordinate(x: x, y: y + 1)
                ) {
                    try require(
                        approximatelyEqual(rect.origin.y + rect.size.height, next.origin.y),
                        "vertical cell rects overlap or leave a gap"
                    )
                }
            }
        }

        let board = geometry.boardRect
        let middleY = board.origin.y + board.size.height / 2
        let middleX = board.origin.x + board.size.width / 2
        try require(
            geometry.coordinate(at: BoardPoint(x: board.origin.x - 0.001, y: middleY)) == nil,
            "point left of board was accepted"
        )
        try require(
            geometry.coordinate(at: BoardPoint(x: middleX, y: board.origin.y - 0.001)) == nil,
            "point above board was accepted"
        )
        try require(
            geometry.coordinate(at: BoardPoint(x: board.origin.x + board.size.width, y: middleY)) == nil,
            "half-open right edge was accepted"
        )
        try require(
            geometry.coordinate(at: BoardPoint(x: middleX, y: board.origin.y + board.size.height)) == nil,
            "half-open bottom edge was accepted"
        )
    }
}

private func validateViewportTransform() throws {
    var geometry = try BoardGeometry(
        columns: 25,
        rows: 25,
        cellSize: 36,
        viewportSize: BoardSize(width: 320, height: 260)
    )
    let anchor = BoardPoint(x: 123, y: 107)
    let before = geometry.unscaledContentPoint(forViewportPoint: anchor)
    geometry.setScale(geometry.scale * 2, anchoredAt: anchor)
    let after = geometry.unscaledContentPoint(forViewportPoint: anchor)
    try require(
        approximatelyEqual(before.x, after.x) && approximatelyEqual(before.y, after.y),
        "anchored zoom moved the logical focus"
    )

    geometry.pan(by: BoardPoint(x: 100_000, y: 100_000))
    try require(
        approximatelyEqual(geometry.translation.x, 0)
            && approximatelyEqual(geometry.translation.y, 0),
        "positive pan did not clamp to the leading/top edge"
    )
    geometry.pan(by: BoardPoint(x: -100_000, y: -100_000))
    try require(
        approximatelyEqual(
            geometry.translation.x,
            geometry.viewportSize.width - geometry.contentSize.width
        ) && approximatelyEqual(
            geometry.translation.y,
            geometry.viewportSize.height - geometry.contentSize.height
        ),
        "negative pan did not clamp to the trailing/bottom edge"
    )
}

private func validateStrokeTransactions(puzzle: PuzzleDefinition) throws -> [CellEdit] {
    guard puzzle.solution.width >= 5, puzzle.solution.height >= 5,
          let colorID = puzzle.palette.first?.colorId else {
        throw boardFailure("representative puzzle must be at least 5×5 with one color")
    }
    let geometry = try BoardGeometry(
        columns: puzzle.solution.width,
        rows: puzzle.solution.height,
        cellSize: 40,
        viewportSize: BoardSize(
            width: Double(puzzle.solution.width) * 40,
            height: Double(puzzle.solution.height) * 40
        )
    )
    let fillState = CellState.filled(colorId: colorID)

    var tap = BoardInputSession(axisLockThreshold: 10)
    try require(
        tap.begin(at: center(of: CellCoordinate(x: 2, y: 2), in: geometry), targetState: fillState, geometry: geometry),
        "tap did not begin"
    )
    let tapEdits = tap.end()
    try require(
        tapEdits == [CellEdit(coordinate: CellCoordinate(x: 2, y: 2), state: fillState)],
        "tap did not create exactly one edit"
    )

    var horizontal = BoardInputSession(axisLockThreshold: 10)
    let horizontalStart = center(of: CellCoordinate(x: 0, y: 0), in: geometry)
    try require(
        horizontal.begin(at: horizontalStart, targetState: fillState, geometry: geometry),
        "horizontal stroke did not begin"
    )
    _ = horizontal.move(
        to: BoardPoint(x: horizontalStart.x + 6, y: horizontalStart.y + 3),
        geometry: geometry
    )
    try require(
        horizontal.axis == .undecided && horizontal.previewCoordinates == [CellCoordinate(x: 0, y: 0)],
        "sub-threshold movement locked an axis"
    )
    _ = horizontal.move(
        to: center(of: CellCoordinate(x: 4, y: 1), in: geometry),
        geometry: geometry
    )
    try require(horizontal.axis == .horizontal, "dominant horizontal drag did not lock horizontally")
    let horizontalEdits = horizontal.end()
    try require(
        horizontalEdits.map(\.coordinate) == (0...4).map { CellCoordinate(x: $0, y: 0) },
        "sparse horizontal sample did not interpolate every cell"
    )
    try require(
        horizontalEdits.allSatisfy { $0.state == fillState },
        "stroke did not preserve its begin-time target state"
    )

    var vertical = BoardInputSession(axisLockThreshold: 10)
    let verticalStart = center(of: CellCoordinate(x: 3, y: 4), in: geometry)
    try require(
        vertical.begin(at: verticalStart, targetState: .excluded, geometry: geometry),
        "vertical stroke did not begin"
    )
    _ = vertical.move(
        to: center(of: CellCoordinate(x: 2, y: 0), in: geometry),
        geometry: geometry
    )
    try require(vertical.axis == .vertical, "dominant vertical drag did not lock vertically")
    try require(
        vertical.end().map(\.coordinate) == (0...4).reversed().map { CellCoordinate(x: 3, y: $0) },
        "reverse vertical sample did not interpolate in gesture order"
    )

    let blocked = CellCoordinate(x: 2, y: 0)
    var filtered = BoardInputSession(axisLockThreshold: 0)
    try require(
        filtered.begin(
            at: horizontalStart,
            targetState: fillState,
            geometry: geometry,
            blockedCoordinates: [blocked]
        ),
        "filtered stroke did not begin"
    )
    _ = filtered.move(to: center(of: CellCoordinate(x: 4, y: 0), in: geometry), geometry: geometry)
    let filteredCoordinates = filtered.end().map(\.coordinate)
    try require(
        filteredCoordinates.count == 4 && !filteredCoordinates.contains(blocked),
        "blocked coordinate was not removed from stroke preview"
    )

    var cancelled = BoardInputSession(axisLockThreshold: 0)
    _ = cancelled.begin(at: horizontalStart, targetState: fillState, geometry: geometry)
    _ = cancelled.move(to: center(of: CellCoordinate(x: 4, y: 0), in: geometry), geometry: geometry)
    cancelled.secondaryTouchBegan()
    try require(
        cancelled.end().isEmpty && !cancelled.isActive && cancelled.previewCoordinates.isEmpty,
        "secondary touch did not cancel pending edits"
    )

    return horizontalEdits
}

private func validateGameSessionBoundary(puzzle: PuzzleDefinition, edits: [CellEdit]) throws {
    var session = try GameSession(puzzle: puzzle)
    let initialCells = session.cells
    let change = try session.applyBatch(edits)
    try require(
        change.changedCoordinates == edits.map(\.coordinate) && change.createdHistoryEntry && session.canUndo,
        "drag was not applied as one history transaction"
    )
    let noOp = try session.applyBatch(edits)
    try require(!noOp.createdHistoryEntry, "no-op stroke created history")
    _ = session.undo()
    try require(
        session.cells == initialCells && !session.canUndo && session.canRedo,
        "one Undo did not revert the complete drag transaction"
    )
    _ = session.redo()
    try require(
        session.cells != initialCells && session.canUndo && !session.canRedo,
        "one Redo did not replay the complete drag transaction"
    )

    var duplicateSession = try GameSession(puzzle: puzzle)
    do {
        _ = try duplicateSession.applyBatch([edits[0], edits[0]])
        throw boardFailure("duplicate batch was accepted")
    } catch let error as GameSessionError {
        guard case .duplicateCoordinate = error else { throw error }
    }
    try require(
        duplicateSession.cells == initialCells && !duplicateSession.canUndo,
        "duplicate batch partially mutated the session"
    )

    var outOfBoundsSession = try GameSession(puzzle: puzzle)
    let outOfBoundsStatus = outOfBoundsSession.completionStatus
    do {
        _ = try outOfBoundsSession.applyBatch([
            edits[0],
            CellEdit(
                coordinate: CellCoordinate(x: puzzle.solution.width, y: 0),
                state: edits[0].state
            ),
        ])
        throw boardFailure("out-of-bounds batch was accepted")
    } catch let error as GameSessionError {
        guard case .coordinateOutOfBounds = error else { throw error }
    }
    try require(
        outOfBoundsSession.cells == initialCells
            && outOfBoundsSession.completionStatus == outOfBoundsStatus
            && !outOfBoundsSession.canUndo,
        "out-of-bounds batch partially mutated the session"
    )

    var unknownColorSession = try GameSession(puzzle: puzzle)
    do {
        _ = try unknownColorSession.applyBatch([
            edits[0],
            CellEdit(coordinate: edits[1].coordinate, state: .filled(colorId: "missing-color")),
        ])
        throw boardFailure("unknown color batch was accepted")
    } catch let error as GameSessionError {
        guard case .unknownColorId = error else { throw error }
    }
    try require(
        unknownColorSession.cells == initialCells && !unknownColorSession.canUndo,
        "unknown-color batch partially mutated the session"
    )

    guard let lockedColorID = puzzle.solution.cells[0] else {
        throw boardFailure("representative puzzle needs a colored first cell")
    }
    let lockedPuzzle = PuzzleDefinition(
        schema: puzzle.schema,
        id: "\(puzzle.id)-locked-input-smoke",
        revision: puzzle.revision,
        kind: .tutorial,
        rulesVersion: puzzle.rulesVersion,
        solverVersion: puzzle.solverVersion,
        palette: puzzle.palette,
        solution: puzzle.solution,
        clues: puzzle.clues,
        prefilledCells: [PrefilledCell(x: 0, y: 0, state: .filled, colorId: lockedColorID)],
        semanticHash: puzzle.semanticHash
    )
    var lockedSession = try GameSession(puzzle: lockedPuzzle)
    let lockedInitialCells = lockedSession.cells
    do {
        _ = try lockedSession.applyBatch([
            CellEdit(coordinate: CellCoordinate(x: 1, y: 0), state: .excluded),
            CellEdit(coordinate: CellCoordinate(x: 0, y: 0), state: .unknown),
        ])
        throw boardFailure("batch touching a locked prefill was accepted")
    } catch let error as GameSessionError {
        guard case .lockedPrefilledCell = error else { throw error }
    }
    try require(
        lockedSession.cells == lockedInitialCells && !lockedSession.canUndo,
        "locked-cell batch partially mutated the session"
    )
}

private func center(of coordinate: CellCoordinate, in geometry: BoardGeometry) -> BoardPoint {
    guard let rect = geometry.cellRect(at: coordinate) else {
        preconditionFailure("Validation requested center of an invalid coordinate")
    }
    return BoardPoint(
        x: rect.origin.x + rect.size.width / 2,
        y: rect.origin.y + rect.size.height / 2
    )
}

private func approximatelyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-8) -> Bool {
    abs(lhs - rhs) <= tolerance
}

private func require(_ condition: @autoclosure () -> Bool, _ reason: String) throws {
    guard condition() else { throw boardFailure(reason) }
}

private func boardFailure(_ reason: String) -> CommandError {
    .boardInputValidationFailed(reason)
}
