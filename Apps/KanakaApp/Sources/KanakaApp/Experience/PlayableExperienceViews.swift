#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaContentKit
import KanakaCore
import SwiftUI

struct PlayableExperienceGate: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let services: KanakaAppServices

    var body: some View {
        switch appModel.experienceState.phase {
        case .worldIntro:
            WorldIntroView(experience: services.catalog.experience)
        case .tutorial:
            TutorialExperienceView(services: services)
        case .routeChoice:
            InitialRouteChoiceView(experience: services.catalog.experience)
        case .ready(let route):
            MainAppShell(services: services, initialRoute: route)
        }
    }
}

private struct WorldIntroView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let experience: PlayableExperienceDefinition
    @State private var pageIndex = 0

    var body: some View {
        let page = experience.introPages[pageIndex]
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.symbolName)
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(localized(page.title))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(localized(page.body))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
                HStack(spacing: 8) {
                    ForEach(experience.introPages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == pageIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == pageIndex ? 28 : 10, height: 8)
                    }
                }
                Button {
                    if pageIndex + 1 < experience.introPages.count {
                        pageIndex += 1
                    } else {
                        Task { await appModel.acknowledgeWorldIntro() }
                    }
                } label: {
                    Label(
                        pageIndex + 1 < experience.introPages.count ? "继续" : "开始校准",
                        systemImage: "arrow.right.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
        }
    }

    private func localized(_ value: LocalizedText) -> String {
        experience.text(value, preferredLocales: Locale.preferredLanguages)
    }
}

@MainActor
private final class TutorialSessionModel: ObservableObject {
    enum Tool: Equatable {
        case fill(String)
        case exclude
        case erase
    }

    @Published private(set) var session: GameSession
    @Published var selectedTool: Tool
    @Published var errorMessage: String?

    init?(puzzle: PuzzleDefinition) {
        guard let session = try? GameSession(puzzle: puzzle) else { return nil }
        self.session = session
        selectedTool = puzzle.palette.first.map { .fill($0.colorId) } ?? .exclude
    }

    var selectedCellState: CellState {
        switch selectedTool {
        case .fill(let colorID): return .filled(colorId: colorID)
        case .exclude: return .excluded
        case .erase: return .unknown
        }
    }

    func edit(_ edits: [CellEdit]) {
        guard !edits.isEmpty else { return }
        do {
            _ = try session.applyBatch(edits)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func edit(_ coordinate: CellCoordinate) {
        edit([CellEdit(coordinate: coordinate, state: selectedCellState)])
    }

    func undo() { _ = session.undo() }
    func redo() { _ = session.redo() }
}

private struct TutorialExperienceView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let services: KanakaAppServices
    let puzzle: PuzzleDefinition
    @StateObject private var model: TutorialSessionModel

    init(services: KanakaAppServices) {
        self.services = services
        let experience = services.catalog.experience
        guard let puzzle = services.catalog.puzzles[experience.tutorial.puzzleID],
              let model = TutorialSessionModel(puzzle: puzzle) else {
            preconditionFailure("Validated playable experience lost its tutorial Puzzle")
        }
        self.puzzle = puzzle
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        let presentation = services.catalog.experience.tutorial
        ScrollView(.vertical) {
            VStack(spacing: 18) {
                Text(localized(presentation.title))
                    .font(.largeTitle.bold())
                Text(localized(presentation.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 680)
                Label("教学是独立练习，不会完成作品或推进故事。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NonogramBoardView(
                    puzzle: puzzle,
                    session: model.session,
                    targetState: model.selectedCellState,
                    edit: model.edit
                )
                tutorialTools
                HStack {
                    Button(localized(presentation.skipLabel)) {
                        Task { await appModel.skipTutorial() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if model.session.isComplete {
                        Button {
                            Task { await appModel.completeTutorial() }
                        } label: {
                            Label(localized(presentation.completeLabel), systemImage: "checkmark.seal.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: 680)
            }
            .padding(24)
        }
        .alert("教学操作失败", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var tutorialTools: some View {
        HStack(spacing: 10) {
            ForEach(puzzle.palette, id: \.colorId) { color in
                let tool = TutorialSessionModel.Tool.fill(color.colorId)
                Button {
                    model.selectedTool = tool
                } label: {
                    VStack {
                        Circle()
                            .fill(Color(sRGB8: color.sRGB8))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(.primary, lineWidth: model.selectedTool == tool ? 3 : 1))
                        Text(color.accessibilitySymbol).font(.caption.bold())
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("填充 \(color.colorId)，符号 \(color.accessibilitySymbol)")
                .accessibilityValue(model.selectedTool == tool ? "已选择" : "未选择")
                .accessibilityAddTraits(model.selectedTool == tool ? .isSelected : [])
            }
            tutorialToolButton("排除", symbol: "xmark", tool: .exclude)
            tutorialToolButton("擦除", symbol: "eraser", tool: .erase)
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.session.canUndo)
                .accessibilityLabel("撤销")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.session.canRedo)
                .accessibilityLabel("重做")
        }
        .buttonStyle(.bordered)
    }

    private func tutorialToolButton(
        _ title: String,
        symbol: String,
        tool: TutorialSessionModel.Tool
    ) -> some View {
        Button {
            model.selectedTool = tool
        } label: {
            Image(systemName: model.selectedTool == tool ? "checkmark.\(symbol)" : symbol)
        }
        .accessibilityLabel(title)
        .accessibilityValue(model.selectedTool == tool ? "已选择" : "未选择")
        .accessibilityAddTraits(model.selectedTool == tool ? .isSelected : [])
    }

    private func localized(_ value: LocalizedText) -> String {
        services.catalog.experience.text(value, preferredLocales: Locale.preferredLanguages)
    }
}

private struct InitialRouteChoiceView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let experience: PlayableExperienceDefinition

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("选择你的起点")
                    .font(.largeTitle.bold())
                Text("两条路径共享内容、进度与权益；进入后仍可随时切换。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ForEach(PlayableExperienceRoute.allCases, id: \.self) { route in
                    if let presentation = experience.route(route) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                localized(presentation.title),
                                systemImage: route == .restoration
                                    ? "paintbrush.pointed" : "square.grid.3x3.fill"
                            )
                            .font(.title2.bold())
                            Text(localized(presentation.subtitle)).font(.headline)
                            Text(localized(presentation.body)).foregroundStyle(.secondary)
                            Button(localized(presentation.actionLabel)) {
                                Task { await appModel.chooseInitialRoute(route) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: 620, alignment: .leading)
                        .padding(20)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(32)
        }
    }

    private func localized(_ value: LocalizedText) -> String {
        experience.text(value, preferredLocales: Locale.preferredLanguages)
    }
}
#endif
