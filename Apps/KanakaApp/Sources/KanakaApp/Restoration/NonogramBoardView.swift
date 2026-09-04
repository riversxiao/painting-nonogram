#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct NonogramBoardView: View {
    let puzzle: PuzzleDefinition
    let session: GameSession
    let targetState: CellState
    let edit: ([CellEdit]) -> Void

    private enum InteractionMode: String, CaseIterable, Identifiable {
        case draw
        case pan

        var id: Self { self }
        var title: String { self == .draw ? "绘制" : "平移" }
        var symbol: String { self == .draw ? "pencil.tip" : "hand.draw" }
    }

    private let logicalCellSize = 42.0
    @State private var geometry: BoardGeometry?
    @State private var inputSession = BoardInputSession()
    @GestureState private var dragGestureIsActive = false
    @GestureState private var magnifyGestureIsActive = false
    @State private var interactionMode: InteractionMode = .draw
    @State private var isTrackingDrag = false
    @State private var dragTrackingID: UUID?
    @State private var lastPanTranslation: CGSize?
    @State private var magnificationStartScale: Double?
    @State private var pinchIsActive = false
    @State private var suppressDragUntilEnd = false
#if canImport(UIKit)
    @State private var rawTouchSequenceIsActive = false
    @State private var rawTouchSequenceIsMultitouch = false
    @State private var rawTouchSequenceIsSuppressed = false
#endif
    @State private var accessibilityCursor = CellCoordinate(x: 0, y: 0)

    var body: some View {
        VStack(spacing: 10) {
            controls
            GeometryReader { proxy in
                let viewport = normalizedViewport(proxy.size)
                let board = Canvas { context, size in
                    let drawingGeometry = geometry ?? makeGeometry(viewport: normalizedViewport(size))
                    drawBoard(context: &context, geometry: drawingGeometry)
                }
                boardInput(for: board)
                    .onAppear { updateViewport(viewport) }
                    .onChange(of: viewport) { _, newViewport in
                        updateViewport(newViewport)
                    }
                    .onDisappear {
                        cancelStrokeForViewportOperation()
                    }
            }
            .frame(minHeight: 320, idealHeight: 500, maxHeight: 620)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("彩色 Nonogram 棋盘，\(session.width) 列，\(session.height) 行")
            .accessibilityValue(accessibilityCursorValue)
            .accessibilityHint("使用命名操作移动逻辑光标或编辑当前格")
            .accessibilityAction(named: Text("向左移动光标")) { moveAccessibilityCursor(dx: -1, dy: 0) }
            .accessibilityAction(named: Text("向右移动光标")) { moveAccessibilityCursor(dx: 1, dy: 0) }
            .accessibilityAction(named: Text("向上移动光标")) { moveAccessibilityCursor(dx: 0, dy: -1) }
            .accessibilityAction(named: Text("向下移动光标")) { moveAccessibilityCursor(dx: 0, dy: 1) }
            .accessibilityAction(named: Text("用当前工具编辑当前格")) { editAccessibilityCursor() }
        }
        .padding(8)
        .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("棋盘交互模式", selection: $interactionMode) {
                ForEach(InteractionMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .onChange(of: interactionMode) { _, _ in
                cancelStrokeForViewportOperation()
            }

            Spacer(minLength: 4)

            Button { zoom(by: 0.8) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("缩小棋盘")

            Button { resetToFit() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("棋盘适合窗口")

            Button { zoom(by: 1.25) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("放大棋盘")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func boardInput<Content: View>(for content: Content) -> some View {
#if canImport(UIKit)
        content
            .overlay {
                RawBoardTouchRepresentable(handle: handleRawTouchEvent)
                    .accessibilityHidden(true)
            }
#else
        content
            .contentShape(Rectangle())
            .gesture(boardDragGesture)
            .simultaneousGesture(boardMagnifyGesture)
            .onChange(of: dragGestureIsActive) { _, active in
                if !active { handleDragGestureInactive() }
            }
            .onChange(of: magnifyGestureIsActive) { _, active in
                if !active { finishMagnification() }
            }
#endif
    }

    private var boardDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($dragGestureIsActive) { _, active, _ in active = true }
            .onChanged { value in
                guard !pinchIsActive, !suppressDragUntilEnd else { return }
                switch interactionMode {
                case .draw:
                    handleDrawChanged(value)
                case .pan:
                    handlePanChanged(value)
                }
            }
            .onEnded { value in
                defer {
                    isTrackingDrag = false
                    dragTrackingID = nil
                    lastPanTranslation = nil
                    if !pinchIsActive { suppressDragUntilEnd = false }
                }
                guard interactionMode == .draw,
                      !pinchIsActive,
                      !suppressDragUntilEnd,
                      inputSession.isActive else { return }
                if let point = boardPoint(value.location), let geometry {
                    inputSession.move(to: point, geometry: geometry)
                    let edits = inputSession.end()
                    if !edits.isEmpty { edit(edits) }
                } else {
                    inputSession.cancel()
                }
            }
    }

    private var boardMagnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyGestureIsActive) { _, active, _ in active = true }
            .onChanged { value in
                guard let currentGeometry = geometry else { return }
                if magnificationStartScale == nil {
                    cancelStrokeForViewportOperation()
                    pinchIsActive = true
                    suppressDragUntilEnd = true
                    magnificationStartScale = currentGeometry.scale
                }
                guard let startScale = magnificationStartScale else { return }
                let anchor = BoardPoint(
                    x: currentGeometry.viewportSize.width * Double(value.startAnchor.x),
                    y: currentGeometry.viewportSize.height * Double(value.startAnchor.y)
                )
                geometry?.setScale(startScale * Double(value.magnification), anchoredAt: anchor)
            }
            .onEnded { _ in
                finishMagnification()
            }
    }

#if canImport(UIKit)
    private func handleRawTouchEvent(_ event: RawBoardTouchEvent) {
        switch event {
        case .primaryBegan(let location):
            rawTouchSequenceIsActive = true
            guard !rawTouchSequenceIsSuppressed,
                  !rawTouchSequenceIsMultitouch,
                  let point = boardPoint(location),
                  let geometry else { return }

            isTrackingDrag = true
            dragTrackingID = UUID()
            lastPanTranslation = nil
            switch interactionMode {
            case .draw:
                _ = inputSession.begin(
                    at: point,
                    targetState: targetState,
                    geometry: geometry,
                    blockedCoordinates: lockedCoordinates
                )
            case .pan:
                inputSession.cancel()
            }

        case .primaryMoved(let previousLocation, let location):
            guard rawTouchSequenceIsActive,
                  !rawTouchSequenceIsSuppressed,
                  !rawTouchSequenceIsMultitouch,
                  dragTrackingID != nil,
                  let point = boardPoint(location) else { return }

            switch interactionMode {
            case .draw:
                guard inputSession.isActive, let geometry else { return }
                inputSession.move(to: point, geometry: geometry)
            case .pan:
                guard let previousPoint = boardPoint(previousLocation) else { return }
                geometry?.pan(by: BoardPoint(
                    x: point.x - previousPoint.x,
                    y: point.y - previousPoint.y
                ))
            }

        case .primaryEnded(let location):
            defer {
                isTrackingDrag = false
                dragTrackingID = nil
                lastPanTranslation = nil
            }
            guard rawTouchSequenceIsActive,
                  !rawTouchSequenceIsSuppressed,
                  !rawTouchSequenceIsMultitouch,
                  dragTrackingID != nil,
                  interactionMode == .draw,
                  inputSession.isActive else { return }

            if let point = boardPoint(location), let geometry {
                inputSession.move(to: point, geometry: geometry)
                let edits = inputSession.end()
                if !edits.isEmpty { edit(edits) }
            } else {
                inputSession.cancel()
            }

        case .secondaryBegan:
            // This event is emitted directly from touchesBegan. Clear the core stroke before
            // UIKit waits for either finger to move or cross a recognizer threshold.
            inputSession.secondaryTouchBegan()
            isTrackingDrag = false
            dragTrackingID = nil
            lastPanTranslation = nil
            rawTouchSequenceIsMultitouch = true
            guard !rawTouchSequenceIsSuppressed, let geometry else { return }
            pinchIsActive = true
            magnificationStartScale = geometry.scale

        case .viewportChanged(let previousCentroid, let centroid, let scaleFactor):
            guard rawTouchSequenceIsActive,
                  rawTouchSequenceIsMultitouch,
                  !rawTouchSequenceIsSuppressed,
                  pinchIsActive,
                  let previousPoint = boardPoint(previousCentroid),
                  let point = boardPoint(centroid) else { return }

            geometry?.pan(by: BoardPoint(
                x: point.x - previousPoint.x,
                y: point.y - previousPoint.y
            ))
            if scaleFactor.isFinite, scaleFactor > 0, let currentScale = geometry?.scale {
                geometry?.setScale(currentScale * scaleFactor, anchoredAt: point)
            }

        case .viewportEnded:
            magnificationStartScale = nil
            pinchIsActive = false
            lastPanTranslation = nil

        case .cancelled:
            rawTouchSequenceIsSuppressed = true
            inputSession.cancel()
            isTrackingDrag = false
            dragTrackingID = nil
            lastPanTranslation = nil
            magnificationStartScale = nil
            pinchIsActive = false

        case .allTouchesEnded:
            inputSession.cancel()
            isTrackingDrag = false
            dragTrackingID = nil
            lastPanTranslation = nil
            magnificationStartScale = nil
            pinchIsActive = false
            rawTouchSequenceIsActive = false
            rawTouchSequenceIsMultitouch = false
            rawTouchSequenceIsSuppressed = false
        }
    }
#endif

    private func handleDrawChanged(_ value: DragGesture.Value) {
        guard let point = boardPoint(value.location), let geometry else { return }
        if !isTrackingDrag {
            isTrackingDrag = true
            dragTrackingID = UUID()
            _ = inputSession.begin(
                at: point,
                targetState: targetState,
                geometry: geometry,
                blockedCoordinates: lockedCoordinates
            )
        }
        if inputSession.isActive {
            inputSession.move(to: point, geometry: geometry)
        }
    }

    private func handlePanChanged(_ value: DragGesture.Value) {
        if lastPanTranslation == nil {
            cancelStrokeForViewportOperation(suppressActiveDrag: false)
            isTrackingDrag = true
            dragTrackingID = UUID()
            lastPanTranslation = .zero
        }
        guard let previous = lastPanTranslation else { return }
        let delta = BoardPoint(
            x: Double(value.translation.width - previous.width),
            y: Double(value.translation.height - previous.height)
        )
        geometry?.pan(by: delta)
        lastPanTranslation = value.translation
    }

    private func zoom(by factor: Double) {
        guard let geometry else { return }
        cancelStrokeForViewportOperation()
        let center = BoardPoint(
            x: geometry.viewportSize.width / 2,
            y: geometry.viewportSize.height / 2
        )
        self.geometry?.setScale(geometry.scale * factor, anchoredAt: center)
    }

    private func resetToFit() {
        cancelStrokeForViewportOperation()
        geometry?.resetToFit()
    }

    private func updateViewport(_ size: CGSize) {
        let viewport = BoardSize(width: Double(size.width), height: Double(size.height))
        if let current = geometry,
           current.columns == puzzle.solution.width,
           current.rows == puzzle.solution.height,
           current.insets == boardInsets {
            guard current.viewportSize != viewport else { return }
            cancelStrokeForViewportOperation()
            try? geometry?.resizeViewport(to: viewport)
        } else {
            cancelStrokeForViewportOperation()
            geometry = makeGeometry(viewport: size)
        }
    }

    private func finishMagnification() {
        magnificationStartScale = nil
        pinchIsActive = false
        if !dragGestureIsActive { suppressDragUntilEnd = false }
    }

    private func handleDragGestureInactive() {
        // GestureState resets for both normal completion and recognizer cancellation. Normal
        // onEnded has already cleared tracking; any remaining identity is an interrupted gesture
        // and must be invalidated synchronously before a new drag can reuse its stroke.
        if dragTrackingID != nil {
            cancelStroke()
            lastPanTranslation = nil
        }
        if !pinchIsActive { suppressDragUntilEnd = false }
    }

    private func cancelStroke() {
        inputSession.cancel()
        isTrackingDrag = false
        dragTrackingID = nil
    }

    private func cancelStrokeForViewportOperation(suppressActiveDrag: Bool = true) {
        inputSession.secondaryTouchBegan()
        isTrackingDrag = false
        dragTrackingID = nil
        lastPanTranslation = nil
        magnificationStartScale = nil
        pinchIsActive = false
#if canImport(UIKit)
        if rawTouchSequenceIsActive {
            rawTouchSequenceIsSuppressed = true
        }
#endif
        if suppressActiveDrag && dragGestureIsActive {
            suppressDragUntilEnd = true
        }
    }

    private func normalizedViewport(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width.isFinite ? max(1, size.width) : 1,
            height: size.height.isFinite ? max(1, size.height) : 1
        )
    }

    private func makeGeometry(viewport: CGSize) -> BoardGeometry {
        do {
            return try BoardGeometry(
                columns: puzzle.solution.width,
                rows: puzzle.solution.height,
                cellSize: logicalCellSize,
                insets: boardInsets,
                viewportSize: BoardSize(width: Double(viewport.width), height: Double(viewport.height)),
                minimumScale: 0.25,
                maximumScale: 4
            )
        } catch {
            preconditionFailure("Validated puzzle produced invalid board geometry: \(error)")
        }
    }

    private var boardInsets: BoardInsets {
        let rowDepth = puzzle.clues.rows.map(\.count).max() ?? 1
        let columnDepth = puzzle.clues.columns.map(\.count).max() ?? 1
        return BoardInsets(
            top: max(58, Double(columnDepth) * 36 + 16),
            leading: max(76, Double(rowDepth) * 64 + 16),
            bottom: 8,
            trailing: 8
        )
    }

    private var lockedCoordinates: Set<CellCoordinate> {
        var result: Set<CellCoordinate> = []
        for row in 0..<session.height {
            for column in 0..<session.width {
                let coordinate = CellCoordinate(x: column, y: row)
                if session.isLocked(coordinate) { result.insert(coordinate) }
            }
        }
        return result
    }

    private func boardPoint(_ point: CGPoint) -> BoardPoint? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return BoardPoint(x: Double(point.x), y: Double(point.y))
    }

    private func drawBoard(context: inout GraphicsContext, geometry: BoardGeometry) {
        drawClues(context: &context, geometry: geometry)
        drawCells(context: &context, geometry: geometry)
        drawGrid(context: &context, geometry: geometry)
    }

    private func drawClues(context: inout GraphicsContext, geometry: BoardGeometry) {
        let board = geometry.boardRect
        let scale = geometry.scale
        let fontSize = CGFloat(max(8, min(16, 12 * scale)))
        let verticalStep = 36 * scale
        let horizontalStep = 64 * scale

        for column in 0..<puzzle.solution.width {
            let clues = puzzle.clues.columns[column]
            let x = board.origin.x + (Double(column) + 0.5) * geometry.cellSize * scale
            for (index, clue) in clues.enumerated() {
                let y = board.origin.y - (Double(clues.count - index) - 0.5) * verticalStep
                drawClue(clue, at: BoardPoint(x: x, y: y), fontSize: fontSize, context: &context)
            }
        }

        for row in 0..<puzzle.solution.height {
            let clues = puzzle.clues.rows[row]
            let y = board.origin.y + (Double(row) + 0.5) * geometry.cellSize * scale
            for (index, clue) in clues.enumerated() {
                let x = board.origin.x - (Double(clues.count - index) - 0.5) * horizontalStep
                drawClue(clue, at: BoardPoint(x: x, y: y), fontSize: fontSize, context: &context)
            }
        }
    }

    private func drawClue(
        _ clue: LineClue,
        at point: BoardPoint,
        fontSize: CGFloat,
        context: inout GraphicsContext
    ) {
        let paletteColor = puzzle.palette.first { $0.colorIndex == clue.colorIndex }
        let symbol = paletteColor?.accessibilitySymbol ?? "?"
        let color = paletteColor.map { Color(sRGB8: $0.sRGB8) } ?? .primary
        let text = Text("\(clue.count)\(symbol)")
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
        context.draw(text, at: CGPoint(x: point.x, y: point.y), anchor: .center)
    }

    private func drawCells(context: inout GraphicsContext, geometry: BoardGeometry) {
        let preview = Set(inputSession.previewCoordinates)
        for row in 0..<session.height {
            for column in 0..<session.width {
                let coordinate = CellCoordinate(x: column, y: row)
                guard let boardRect = geometry.cellRect(at: coordinate) else { continue }
                let rect = cgRect(boardRect)
                let state = (try? session.cell(at: coordinate)) ?? .unknown
                context.fill(Path(rect), with: .color(cellBackground(state)))
                drawCellSymbol(state, in: rect, scale: geometry.scale, context: &context)

                if session.isLocked(coordinate) {
                    let inset = max(1, CGFloat(geometry.scale * 2))
                    context.stroke(
                        Path(rect.insetBy(dx: inset, dy: inset)),
                        with: .color(.primary.opacity(0.75)),
                        lineWidth: max(1, CGFloat(geometry.scale * 2))
                    )
                    let lockText = Text("锁")
                        .font(.system(size: max(7, CGFloat(9 * geometry.scale)), weight: .bold))
                        .foregroundStyle(.primary)
                    context.draw(
                        lockText,
                        at: CGPoint(x: rect.maxX - inset - 2, y: rect.minY + inset + 2),
                        anchor: .topTrailing
                    )
                }

                if preview.contains(coordinate) {
                    context.fill(Path(rect), with: .color(.accentColor.opacity(0.24)))
                    context.stroke(
                        Path(rect.insetBy(dx: 1, dy: 1)),
                        with: .color(.accentColor),
                        lineWidth: max(2, CGFloat(geometry.scale * 2.5))
                    )
                }

                if coordinate == accessibilityCursor {
                    context.stroke(
                        Path(rect.insetBy(dx: 2, dy: 2)),
                        with: .color(.orange),
                        lineWidth: max(2, CGFloat(geometry.scale * 3))
                    )
                }
            }
        }
    }

    private func drawCellSymbol(
        _ state: CellState,
        in rect: CGRect,
        scale: Double,
        context: inout GraphicsContext
    ) {
        let fontSize = max(8, min(rect.width * 0.48, CGFloat(19 * scale)))
        switch state {
        case .unknown:
            break
        case .excluded:
            var mark = Path()
            let inset = max(3, rect.width * 0.28)
            mark.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
            mark.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
            mark.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
            mark.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
            context.stroke(mark, with: .color(.secondary), lineWidth: max(1.5, CGFloat(scale * 2)))
        case .filled(let colorID):
            let symbol = puzzle.palette.first { $0.colorId == colorID }?.accessibilitySymbol ?? "?"
            context.draw(
                Text(symbol)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(symbolForeground(for: colorID)),
                at: CGPoint(x: rect.midX, y: rect.midY),
                anchor: .center
            )
        }
    }

    private func drawGrid(context: inout GraphicsContext, geometry: BoardGeometry) {
        let board = geometry.boardRect
        var minor = Path()
        var major = Path()
        for column in 0...puzzle.solution.width {
            let x = board.origin.x + Double(column) * geometry.cellSize * geometry.scale
            let target = column.isMultiple(of: 5) ? major : minor
            var line = target
            line.move(to: CGPoint(x: x, y: board.origin.y))
            line.addLine(to: CGPoint(x: x, y: board.origin.y + board.size.height))
            if column.isMultiple(of: 5) { major = line } else { minor = line }
        }
        for row in 0...puzzle.solution.height {
            let y = board.origin.y + Double(row) * geometry.cellSize * geometry.scale
            let target = row.isMultiple(of: 5) ? major : minor
            var line = target
            line.move(to: CGPoint(x: board.origin.x, y: y))
            line.addLine(to: CGPoint(x: board.origin.x + board.size.width, y: y))
            if row.isMultiple(of: 5) { major = line } else { minor = line }
        }
        context.stroke(minor, with: .color(.primary.opacity(0.42)), lineWidth: 0.75)
        context.stroke(major, with: .color(.primary.opacity(0.75)), lineWidth: 1.5)
    }

    private func cellBackground(_ state: CellState) -> Color {
        guard case .filled(let colorID) = state,
              let paletteColor = puzzle.palette.first(where: { $0.colorId == colorID }) else {
            return .white
        }
        return Color(sRGB8: paletteColor.sRGB8)
    }

    private func symbolForeground(for colorID: String) -> Color {
        guard let rgb = puzzle.palette.first(where: { $0.colorId == colorID })?.sRGB8 else {
            return .primary
        }
        let brightness = (
            0.299 * Double(rgb.r)
                + 0.587 * Double(rgb.g)
                + 0.114 * Double(rgb.b)
        ) / 255
        return brightness > 0.58 ? .black : .white
    }

    private func cgRect(_ rect: BoardRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    private var accessibilityCursorValue: String {
        let coordinate = clampedAccessibilityCursor
        let state = (try? session.cell(at: coordinate)) ?? .unknown
        let stateText: String
        switch state {
        case .unknown:
            stateText = "未知"
        case .excluded:
            stateText = "排除，符号叉号"
        case .filled(let colorID):
            let symbol = puzzle.palette.first { $0.colorId == colorID }?.accessibilitySymbol ?? "?"
            stateText = "填充 \(colorID)，符号 \(symbol)"
        }
        let lockText = session.isLocked(coordinate) ? "，锁定，不能修改" : ""
        let previewText = inputSession.previewCoordinates.isEmpty
            ? ""
            : "，正在预览 \(inputSession.previewCoordinates.count) 格，轴向 \(inputSession.axis.rawValue)"
        return "光标第 \(coordinate.y + 1) 行，第 \(coordinate.x + 1) 列，\(stateText)\(lockText)\(previewText)"
    }

    private var clampedAccessibilityCursor: CellCoordinate {
        CellCoordinate(
            x: min(max(accessibilityCursor.x, 0), max(0, session.width - 1)),
            y: min(max(accessibilityCursor.y, 0), max(0, session.height - 1))
        )
    }

    private func moveAccessibilityCursor(dx: Int, dy: Int) {
        let current = clampedAccessibilityCursor
        accessibilityCursor = CellCoordinate(
            x: min(max(current.x + dx, 0), session.width - 1),
            y: min(max(current.y + dy, 0), session.height - 1)
        )
    }

    private func editAccessibilityCursor() {
        let coordinate = clampedAccessibilityCursor
        guard !session.isLocked(coordinate) else { return }
        edit([CellEdit(coordinate: coordinate, state: targetState)])
    }
}

#if canImport(UIKit)
private enum RawBoardTouchEvent {
    case primaryBegan(CGPoint)
    case primaryMoved(previous: CGPoint, current: CGPoint)
    case primaryEnded(CGPoint)
    case secondaryBegan
    case viewportChanged(previousCentroid: CGPoint, centroid: CGPoint, scaleFactor: Double)
    case viewportEnded
    case cancelled
    case allTouchesEnded
}

private struct RawBoardTouchRepresentable: UIViewRepresentable {
    let handle: (RawBoardTouchEvent) -> Void

    func makeUIView(context: Context) -> RawBoardTouchView {
        let view = RawBoardTouchView()
        view.handle = handle
        return view
    }

    func updateUIView(_ view: RawBoardTouchView, context: Context) {
        view.handle = handle
    }

    static func dismantleUIView(_ view: RawBoardTouchView, coordinator: ()) {
        view.cancelActiveSequence()
        view.handle = nil
    }
}

private final class RawBoardTouchView: UIView {
    var handle: ((RawBoardTouchEvent) -> Void)?

    private enum SequenceState {
        case idle
        case single(primary: ObjectIdentifier, previousLocation: CGPoint)
        case multiple(
            first: ObjectIdentifier,
            second: ObjectIdentifier,
            previousCentroid: CGPoint,
            previousDistance: CGFloat
        )
        case ignoring
    }

    private var state: SequenceState = .idle
    private var activeTouches: [ObjectIdentifier: UITouch] = [:]
    private var touchOrder: [ObjectIdentifier] = []
    private weak var lockedAncestorScrollView: UIScrollView?
    private var ancestorScrollWasEnabled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeTouches.isEmpty {
            lockNearestAncestorScrollView()
        }
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            if activeTouches[identifier] == nil {
                activeTouches[identifier] = touch
                touchOrder.append(identifier)
            }
        }

        switch state {
        case .idle:
            guard let primary = touchOrder.first,
                  let touch = activeTouches[primary] else { return }
            let location = touch.location(in: self)
            state = .single(primary: primary, previousLocation: location)
            handle?(.primaryBegan(location))
            if activeTouches.count > 1 {
                beginMultipleTouchSequence()
            }

        case .single:
            if activeTouches.count > 1 {
                beginMultipleTouchSequence()
            }

        case .multiple:
            if activeTouches.count > 2 {
                failClosed()
            }

        case .ignoring:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .idle, .ignoring:
            return

        case .single(let primary, let previousLocation):
            guard touches.contains(where: { ObjectIdentifier($0) == primary }),
                  let touch = activeTouches[primary] else { return }
            let location = touch.location(in: self)
            state = .single(primary: primary, previousLocation: location)
            handle?(.primaryMoved(previous: previousLocation, current: location))

        case .multiple(let first, let second, let previousCentroid, let previousDistance):
            guard let firstTouch = activeTouches[first],
                  let secondTouch = activeTouches[second] else {
                failClosed()
                return
            }
            let current = metrics(firstTouch: firstTouch, secondTouch: secondTouch)
            let scaleFactor: Double
            if previousDistance.isFinite, previousDistance > .ulpOfOne,
               current.distance.isFinite, current.distance > 0 {
                scaleFactor = Double(current.distance / previousDistance)
            } else {
                scaleFactor = 1
            }
            state = .multiple(
                first: first,
                second: second,
                previousCentroid: current.centroid,
                previousDistance: current.distance
            )
            handle?(.viewportChanged(
                previousCentroid: previousCentroid,
                centroid: current.centroid,
                scaleFactor: scaleFactor
            ))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .idle:
            remove(touches)

        case .single(let primary, _):
            if let touch = touches.first(where: { ObjectIdentifier($0) == primary }) {
                handle?(.primaryEnded(touch.location(in: self)))
            } else {
                handle?(.cancelled)
            }
            state = .ignoring
            remove(touches)

        case .multiple:
            handle?(.viewportEnded)
            state = .ignoring
            remove(touches)

        case .ignoring:
            remove(touches)
        }

        finishSequenceIfNeeded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !activeTouches.isEmpty {
            failClosed()
        }
        remove(touches)
        finishSequenceIfNeeded()
    }

    func cancelActiveSequence() {
        guard !activeTouches.isEmpty else { return }
        failClosed()
        activeTouches.removeAll()
        touchOrder.removeAll()
        finishSequenceIfNeeded()
    }

    private func beginMultipleTouchSequence() {
        handle?(.secondaryBegan)
        guard activeTouches.count == 2,
              touchOrder.count >= 2,
              let firstTouch = activeTouches[touchOrder[0]],
              let secondTouch = activeTouches[touchOrder[1]] else {
            failClosed()
            return
        }
        let current = metrics(firstTouch: firstTouch, secondTouch: secondTouch)
        state = .multiple(
            first: touchOrder[0],
            second: touchOrder[1],
            previousCentroid: current.centroid,
            previousDistance: current.distance
        )
    }

    private func failClosed() {
        if case .ignoring = state { return }
        handle?(.cancelled)
        state = .ignoring
    }

    private func remove(_ touches: Set<UITouch>) {
        let removed = Set(touches.map(ObjectIdentifier.init))
        for identifier in removed {
            activeTouches.removeValue(forKey: identifier)
        }
        touchOrder.removeAll { removed.contains($0) }
    }

    private func finishSequenceIfNeeded() {
        guard activeTouches.isEmpty else { return }
        state = .idle
        touchOrder.removeAll()
        restoreAncestorScrollView()
        handle?(.allTouchesEnded)
    }

    /// The board owns a touch sequence once it begins. Temporarily disabling the nearest host
    /// scroll view prevents its pan recognizer from cancelling a draw before the board sees end.
    private func lockNearestAncestorScrollView() {
        guard lockedAncestorScrollView == nil else { return }
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                lockedAncestorScrollView = scrollView
                ancestorScrollWasEnabled = scrollView.isScrollEnabled
                if ancestorScrollWasEnabled { scrollView.isScrollEnabled = false }
                return
            }
            ancestor = view.superview
        }
    }

    private func restoreAncestorScrollView() {
        if ancestorScrollWasEnabled {
            lockedAncestorScrollView?.isScrollEnabled = true
        }
        lockedAncestorScrollView = nil
        ancestorScrollWasEnabled = false
    }

    private func metrics(firstTouch: UITouch, secondTouch: UITouch) -> (
        centroid: CGPoint,
        distance: CGFloat
    ) {
        let first = firstTouch.location(in: self)
        let second = secondTouch.location(in: self)
        let centroid = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        return (centroid, hypot(second.x - first.x, second.y - first.y))
    }
}
#endif
#endif
