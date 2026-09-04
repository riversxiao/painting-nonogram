#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaCore
import KanakaProductDomain
import SwiftUI

@MainActor
final class PuzzleViewModel: ObservableObject {
    enum Tool: Equatable {
        case fill(String)
        case exclude
        case erase
    }

    @Published private(set) var session: GameSession?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isClosing = false
    @Published private(set) var isReadOnly = false
    @Published private(set) var outcome: FragmentCompletionOutcome?
    @Published var selectedTool: Tool
    @Published var errorMessage: String?

    let fragmentID: String
    let puzzle: PuzzleDefinition

    private let services: KanakaAppServices
    private var controller: PuzzleSessionController?
    private var registryToken: UUID?
    private var operationTail: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    init(services: KanakaAppServices, fragmentID: String, puzzle: PuzzleDefinition) {
        self.services = services
        self.fragmentID = fragmentID
        self.puzzle = puzzle
        selectedTool = puzzle.palette.first.map { .fill($0.colorId) } ?? .exclude
    }

    func load() async {
        guard controller == nil, !isClosing else { return }
        await serialize { [weak self] in
            guard let self, self.controller == nil, !self.isClosing else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            do {
                let opened = try await self.services.flow.openFragment(self.fragmentID)
                guard !self.isClosing else {
                    try await opened.flush()
                    return
                }
                self.controller = opened
                self.registryToken = await self.services.sessions.register(opened)
                self.session = await opened.currentSession()
                self.isReadOnly = await opened.isFinalized()
            } catch {
                self.errorMessage = String(describing: error)
            }
        }
    }

    var selectedCellState: CellState {
        switch selectedTool {
        case .fill(let colorID): return .filled(colorId: colorID)
        case .exclude: return .excluded
        case .erase: return .unknown
        }
    }

    func edit(_ edits: [CellEdit]) async {
        guard !edits.isEmpty, !isClosing, !isReadOnly else { return }
        await serialize { [weak self] in
            guard let self, let controller = self.controller else { return }
            do {
                _ = try await controller.apply(edits)
                self.session = await controller.currentSession()
            } catch {
                self.errorMessage = String(describing: error)
            }
        }
    }

    func edit(_ coordinate: CellCoordinate) async {
        await edit([CellEdit(coordinate: coordinate, state: selectedCellState)])
    }

    func undo() async {
        guard !isClosing, !isReadOnly else { return }
        await serialize { [weak self] in
            guard let self, let controller = self.controller else { return }
            do {
                _ = try await controller.undo()
                self.session = await controller.currentSession()
            } catch {
                self.errorMessage = String(describing: error)
            }
        }
    }

    func redo() async {
        guard !isClosing, !isReadOnly else { return }
        await serialize { [weak self] in
            guard let self, let controller = self.controller else { return }
            do {
                _ = try await controller.redo()
                self.session = await controller.currentSession()
            } catch {
                self.errorMessage = String(describing: error)
            }
        }
    }

    func complete(entitlements: MuseumEntitlementSnapshot) async {
        guard !isClosing, !isReadOnly, session?.isComplete == true, outcome == nil else { return }
        await serialize { [weak self] in
            guard let self, let controller = self.controller else { return }
            self.isSaving = true
            defer { self.isSaving = false }
            do {
                self.outcome = try await self.services.flow.complete(
                    controller,
                    entitlements: entitlements
                )
                self.session = await controller.currentSession()
                self.isReadOnly = true
            } catch {
                self.errorMessage = String(describing: error)
            }
        }
    }

    /// Stops admission of new mutations synchronously, then waits for admitted work before the
    /// final flush. `onDisappear` uses this non-async entry point so no new tap task can overtake it.
    func beginClosing() {
        guard !isClosing else { return }
        isClosing = true
        closeTask = Task { [weak self] in
            await self?.finishClosing()
        }
    }

    func flushAndClose() async {
        beginClosing()
        await closeTask?.value
    }

    private func finishClosing() async {
        await serialize { [weak self] in
            guard let self else { return }
            do {
                if let token = self.registryToken {
                    try await self.services.sessions.flushAndUnregister(token)
                    self.registryToken = nil
                } else if let controller = self.controller {
                    try await controller.flush()
                }
            } catch {
                self.errorMessage = "离开前保存失败：\(error)"
            }
        }
    }

    private func serialize(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = operationTail
        let task = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
        }
        operationTail = task
        await task.value
    }
}
#endif
