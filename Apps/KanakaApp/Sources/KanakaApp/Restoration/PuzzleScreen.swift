#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaContentKit
import KanakaCore
import SwiftUI

struct PuzzleScreen: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    @StateObject private var model: PuzzleViewModel

    init(services: KanakaAppServices, fragment: RepairFragmentDefinition) {
        guard let puzzle = services.catalog.puzzles[fragment.puzzleDefinitionID] else {
            preconditionFailure("Validated catalog lost Puzzle \(fragment.puzzleDefinitionID)")
        }
        _model = StateObject(wrappedValue: PuzzleViewModel(
            services: services,
            fragmentID: fragment.id,
            puzzle: puzzle
        ))
    }

    var body: some View {
        Group {
            if let session = model.session {
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 16) {
                        PuzzleStatusView(session: session)
                        NonogramBoardView(
                            puzzle: model.puzzle,
                            session: session,
                            edit: { coordinate in Task { await model.edit(coordinate) } }
                        )
                        .disabled(model.isReadOnly || model.isClosing)
                        ToolPalette(model: model, session: session)
                            .disabled(model.isReadOnly || model.isClosing)
                        if model.isReadOnly {
                            Label("该完成记录已冻结；重玩将使用独立记录。", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if session.isComplete && !model.isReadOnly {
                            Button {
                                Task { await model.complete(entitlements: appModel.entitlementSnapshot) }
                            } label: {
                                Label("提交修复", systemImage: "checkmark.seal.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isSaving || model.outcome != nil)
                        }
                        if let outcome = model.outcome {
                            CompletionSummary(outcome: outcome)
                        }
                    }
                    .padding()
                }
            } else if model.isLoading {
                ProgressView("正在恢复会话…")
            } else {
                ContentUnavailableView("无法打开谜题", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(displayName(model.fragmentID))
        .task { await model.load() }
        .onDisappear { model.beginClosing() }
        .alert("修复操作失败", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct PuzzleStatusView: View {
    let session: GameSession

    var body: some View {
        HStack {
            Label("\(session.width) × \(session.height)", systemImage: "square.grid.3x3")
            Spacer()
            Text(session.completionStatus == .incomplete ? "修复中" : "答案完成")
                .font(.headline)
                .foregroundStyle(session.isComplete ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ToolPalette: View {
    @ObservedObject var model: PuzzleViewModel
    let session: GameSession

    var body: some View {
        HStack(spacing: 10) {
            ForEach(session.palette, id: \.colorId) { color in
                let tool = PuzzleViewModel.Tool.fill(color.colorId)
                let isSelected = selected(tool)
                Button {
                    model.selectedTool = tool
                } label: {
                    VStack {
                        Circle()
                            .fill(Color(sRGB8: color.sRGB8))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(.primary, lineWidth: isSelected ? 3 : 1))
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, Color.accentColor)
                                        .background(Circle().fill(.background))
                                        .offset(x: 5, y: -5)
                                }
                            }
                        Text(color.accessibilitySymbol).font(.caption.bold())
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("填充 \(color.colorId)，符号 \(color.accessibilitySymbol)")
                .accessibilityValue(isSelected ? "已选择" : "未选择")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            toolButton("排除", symbol: "xmark", tool: .exclude)
            toolButton("擦除", symbol: "eraser", tool: .erase)
            Button { Task { await model.undo() } } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!session.canUndo)
                .accessibilityLabel("撤销")
            Button { Task { await model.redo() } } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!session.canRedo)
                .accessibilityLabel("重做")
        }
        .buttonStyle(.bordered)
    }

    private func toolButton(_ title: String, symbol: String, tool: PuzzleViewModel.Tool) -> some View {
        Button {
            model.selectedTool = tool
        } label: {
            ZStack(alignment: .topTrailing) {
                Label(title, systemImage: symbol)
                    .labelStyle(.iconOnly)
                if selected(tool) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .offset(x: 7, y: -7)
                }
            }
        }
        .tint(selected(tool) ? .accentColor : nil)
        .accessibilityLabel(title)
        .accessibilityValue(selected(tool) ? "已选择" : "未选择")
        .accessibilityAddTraits(selected(tool) ? .isSelected : [])
    }

    private func selected(_ tool: PuzzleViewModel.Tool) -> Bool { model.selectedTool == tool }
}

private struct CompletionSummary: View {
    let outcome: FragmentCompletionOutcome

    var body: some View {
        VStack(spacing: 8) {
            Label("片段已持久化", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("作品进度 \(outcome.receipt.completedCount) / \(outcome.receipt.totalCount)")
            if outcome.artworkState.access.artworkRestored {
                Text("整幅作品已恢复，Blueprint 与亲手修复印章已解锁。")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension Color {
    init(sRGB8: SRGB8) {
        self.init(
            .sRGB,
            red: Double(sRGB8.r) / 255,
            green: Double(sRGB8.g) / 255,
            blue: Double(sRGB8.b) / 255,
            opacity: 1
        )
    }
}
#endif
