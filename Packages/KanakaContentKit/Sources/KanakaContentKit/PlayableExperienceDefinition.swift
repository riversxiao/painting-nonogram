import Foundation

public enum PlayableExperienceSchema {
    public static let definition = "playable-experience-v1"
}

public enum PlayableExperienceRoute: String, Codable, CaseIterable, Equatable, Sendable {
    case restoration
    case workshop
}

public struct LocalizedText: Codable, Equatable, Sendable {
    public let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public init(from decoder: any Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public func resolved(
        preferredLocales: [String],
        defaultLocale: String
    ) -> String {
        var candidates: [String] = []
        for locale in preferredLocales + [defaultLocale, "en"] {
            var parts = locale.replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .map(String.init)
            while !parts.isEmpty {
                candidates.append(parts.joined(separator: "-"))
                parts.removeLast()
            }
        }
        for candidate in candidates {
            if let value = values[candidate], !value.isEmpty { return value }
        }
        return values.sorted(by: { $0.key < $1.key }).first?.value ?? ""
    }
}

public struct ExperienceIntroPage: Codable, Equatable, Sendable {
    public let id: String
    public let title: LocalizedText
    public let body: LocalizedText
    public let symbolName: String
}

public struct ExperienceTutorialPresentation: Codable, Equatable, Sendable {
    public let puzzleID: String
    public let title: LocalizedText
    public let body: LocalizedText
    public let skipLabel: LocalizedText
    public let completeLabel: LocalizedText
}

public struct ExperienceRoutePresentation: Codable, Equatable, Sendable {
    public let route: PlayableExperienceRoute
    public let title: LocalizedText
    public let subtitle: LocalizedText
    public let body: LocalizedText
    public let actionLabel: LocalizedText
}

public struct ExperienceEntityPresentation: Codable, Equatable, Sendable {
    public let id: String
    public let title: LocalizedText
    public let subtitle: LocalizedText?
    public let body: LocalizedText?
    public let completionTitle: LocalizedText?
    public let completionBody: LocalizedText?
}

public struct PlayableExperienceDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let revision: Int
    public let defaultLocale: String
    public let supportedLocales: [String]
    public let introPages: [ExperienceIntroPage]
    public let tutorial: ExperienceTutorialPresentation
    public let routes: [ExperienceRoutePresentation]
    public let museums: [ExperienceEntityPresentation]
    public let galleries: [ExperienceEntityPresentation]
    public let artworks: [ExperienceEntityPresentation]
    public let fragments: [ExperienceEntityPresentation]

    public func introPage(id: String) -> ExperienceIntroPage? {
        introPages.first { $0.id == id }
    }

    public func route(_ route: PlayableExperienceRoute) -> ExperienceRoutePresentation? {
        routes.first { $0.route == route }
    }

    public func museum(_ id: String) -> ExperienceEntityPresentation? {
        museums.first { $0.id == id }
    }

    public func gallery(_ id: String) -> ExperienceEntityPresentation? {
        galleries.first { $0.id == id }
    }

    public func artwork(_ id: String) -> ExperienceEntityPresentation? {
        artworks.first { $0.id == id }
    }

    public func fragment(_ id: String) -> ExperienceEntityPresentation? {
        fragments.first { $0.id == id }
    }

    public func text(
        _ value: LocalizedText,
        preferredLocales: [String]
    ) -> String {
        value.resolved(
            preferredLocales: preferredLocales,
            defaultLocale: defaultLocale
        )
    }
}
