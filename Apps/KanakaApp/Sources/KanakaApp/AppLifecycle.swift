#if canImport(SwiftUI)
import Foundation
import KanakaProductDomain

actor ActivePuzzleSessionRegistry {
    struct FlushFailure: Sendable {
        let fragmentID: String
        let reason: String
    }

    private var sessions: [UUID: PuzzleSessionController] = [:]

    func register(_ controller: PuzzleSessionController) -> UUID {
        let token = UUID()
        sessions[token] = controller
        return token
    }

    func flushAndUnregister(_ token: UUID) async throws {
        guard let controller = sessions[token] else { return }
        try await controller.flush()
        sessions.removeValue(forKey: token)
    }

    func flushAll() async -> [FlushFailure] {
        var failures: [FlushFailure] = []
        for controller in sessions.values {
            do {
                try await controller.flush()
            } catch {
                failures.append(FlushFailure(
                    fragmentID: controller.fragmentID,
                    reason: String(describing: error)
                ))
            }
        }
        return failures
    }
}
#endif
