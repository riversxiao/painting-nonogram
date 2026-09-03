#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaCore
import SwiftUI

struct NonogramBoardView: View {
    let puzzle: PuzzleDefinition
    let session: GameSession
    let edit: (CellCoordinate) -> Void

    private let cellSize: CGFloat = 42

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                Color.clear.frame(width: 120, height: 80)
                ForEach(0..<puzzle.solution.width, id: \.self) { column in
                    clueStack(puzzle.clues.columns[column], vertical: true)
                        .frame(width: cellSize, height: 80, alignment: .bottom)
                }
            }
            ForEach(0..<puzzle.solution.height, id: \.self) { row in
                GridRow {
                    clueStack(puzzle.clues.rows[row], vertical: false)
                        .frame(width: 120, height: cellSize, alignment: .trailing)
                    ForEach(0..<puzzle.solution.width, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .padding(6)
        .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("彩色 Nonogram 棋盘，\(session.width) 列，\(session.height) 行")
    }

    @ViewBuilder
    private func clueStack(_ clues: [LineClue], vertical: Bool) -> some View {
        let content = ForEach(Array(clues.enumerated()), id: \.offset) { _, clue in
            let color = puzzle.palette.first(where: { $0.colorIndex == clue.colorIndex })
            Text("\(clue.count)\(color?.accessibilitySymbol ?? "?")")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color.map { Color(sRGB8: $0.sRGB8) } ?? Color.primary)
        }
        if vertical { VStack(spacing: 1) { content } }
        else { HStack(spacing: 4) { content } }
    }

    private func cell(row: Int, column: Int) -> some View {
        let coordinate = CellCoordinate(x: column, y: row)
        let state = (try? session.cell(at: coordinate)) ?? .unknown
        let locked = session.isLocked(coordinate)
        return Button {
            edit(coordinate)
        } label: {
            ZStack {
                Rectangle().fill(cellBackground(state))
                Rectangle().stroke(.primary.opacity(0.55), lineWidth: 1)
                cellSymbol(state)
            }
            .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(cellAccessibilityLabel(
            row: row,
            column: column,
            state: state,
            locked: locked
        ))
        .accessibilityHint(locked ? "教学预填格，不能修改" : "使用当前工具修改此格")
    }

    private func cellBackground(_ state: CellState) -> Color {
        guard case .filled(let colorID) = state,
              let color = puzzle.palette.first(where: { $0.colorId == colorID }) else {
            return .white
        }
        return Color(sRGB8: color.sRGB8)
    }

    @ViewBuilder
    private func cellSymbol(_ state: CellState) -> some View {
        switch state {
        case .unknown:
            EmptyView()
        case .excluded:
            Image(systemName: "xmark").foregroundStyle(.secondary)
        case .filled(let colorID):
            Text(puzzle.palette.first(where: { $0.colorId == colorID })?.accessibilitySymbol ?? "?")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .shadow(radius: 1)
        }
    }

    private func cellAccessibilityLabel(
        row: Int,
        column: Int,
        state: CellState,
        locked: Bool
    ) -> String {
        let stateText: String
        switch state {
        case .unknown: stateText = "未知"
        case .excluded: stateText = "排除"
        case .filled(let colorID):
            let symbol = puzzle.palette.first(where: { $0.colorId == colorID })?.accessibilitySymbol ?? "?"
            stateText = "填充 \(colorID)，符号 \(symbol)"
        }
        return "第 \(row + 1) 行，第 \(column + 1) 列，\(stateText)\(locked ? "，锁定" : "")"
    }
}
#endif
