#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaProductDomain

actor UserDefaultsPlayableExperienceStateStore: PlayableExperienceStateStore {
    private let key = "kanaka.playable-experience-state.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async throws -> PlayableExperienceState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(PlayableExperienceState.self, from: data)
    }

    func save(_ state: PlayableExperienceState) async throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
}
#endif
