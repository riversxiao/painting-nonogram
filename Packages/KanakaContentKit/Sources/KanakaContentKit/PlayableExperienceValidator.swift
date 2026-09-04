import KanakaCore

public enum PlayableExperienceValidationError: Error, Equatable, CustomStringConvertible {
    case invalidField(String)
    case duplicate(kind: String, id: String)
    case coverageMismatch(kind: String)
    case missingPuzzle(String)
    case invalidTutorialDimensions(width: Int, height: Int)

    public var description: String {
        switch self {
        case .invalidField(let field):
            "Invalid playable experience field: \(field)"
        case .duplicate(let kind, let id):
            "Duplicate playable experience \(kind): \(id)"
        case .coverageMismatch(let kind):
            "Playable experience presentation does not exactly cover \(kind)"
        case .missingPuzzle(let id):
            "Playable experience tutorial references missing Puzzle \(id)"
        case .invalidTutorialDimensions(let width, let height):
            "Playable experience tutorial must be 5×5, found \(width)×\(height)"
        }
    }
}

public enum PlayableExperienceValidator {
    public static func validate(
        _ definition: PlayableExperienceDefinition,
        museumIDs: Set<String>,
        galleryIDs: Set<String>,
        artworkIDs: Set<String>,
        fragmentIDs: Set<String>,
        puzzles: [String: PuzzleDefinition]
    ) throws {
        guard definition.schema == PlayableExperienceSchema.definition,
              definition.revision > 0,
              !definition.defaultLocale.isEmpty,
              !definition.supportedLocales.isEmpty,
              Set(definition.supportedLocales).count == definition.supportedLocales.count,
              definition.supportedLocales.contains(definition.defaultLocale),
              !definition.introPages.isEmpty else {
            throw PlayableExperienceValidationError.invalidField("header, locales, or intro pages")
        }

        try requireUnique(definition.introPages.map(\.id), kind: "intro page")
        for page in definition.introPages {
            guard !page.id.isEmpty, !page.symbolName.isEmpty else {
                throw PlayableExperienceValidationError.invalidField("intro page identity")
            }
            try validate(page.title, defaultLocale: definition.defaultLocale)
            try validate(page.body, defaultLocale: definition.defaultLocale)
        }

        let routeValues = definition.routes.map(\.route)
        guard Set(routeValues) == Set(PlayableExperienceRoute.allCases),
              routeValues.count == PlayableExperienceRoute.allCases.count else {
            throw PlayableExperienceValidationError.coverageMismatch(kind: "initial routes")
        }
        for route in definition.routes {
            try validate(route.title, defaultLocale: definition.defaultLocale)
            try validate(route.subtitle, defaultLocale: definition.defaultLocale)
            try validate(route.body, defaultLocale: definition.defaultLocale)
            try validate(route.actionLabel, defaultLocale: definition.defaultLocale)
        }

        guard let tutorialPuzzle = puzzles[definition.tutorial.puzzleID] else {
            throw PlayableExperienceValidationError.missingPuzzle(definition.tutorial.puzzleID)
        }
        guard tutorialPuzzle.solution.width == 5, tutorialPuzzle.solution.height == 5 else {
            throw PlayableExperienceValidationError.invalidTutorialDimensions(
                width: tutorialPuzzle.solution.width,
                height: tutorialPuzzle.solution.height
            )
        }
        try validate(definition.tutorial.title, defaultLocale: definition.defaultLocale)
        try validate(definition.tutorial.body, defaultLocale: definition.defaultLocale)
        try validate(definition.tutorial.skipLabel, defaultLocale: definition.defaultLocale)
        try validate(definition.tutorial.completeLabel, defaultLocale: definition.defaultLocale)

        try validatePresentations(
            definition.museums,
            expectedIDs: museumIDs,
            kind: "Museums",
            defaultLocale: definition.defaultLocale,
            requiresCompletionCopy: false
        )
        try validatePresentations(
            definition.galleries,
            expectedIDs: galleryIDs,
            kind: "Galleries",
            defaultLocale: definition.defaultLocale,
            requiresCompletionCopy: false
        )
        try validatePresentations(
            definition.artworks,
            expectedIDs: artworkIDs,
            kind: "Artworks",
            defaultLocale: definition.defaultLocale,
            requiresCompletionCopy: true
        )
        try validatePresentations(
            definition.fragments,
            expectedIDs: fragmentIDs,
            kind: "Fragments",
            defaultLocale: definition.defaultLocale,
            requiresCompletionCopy: true
        )
    }

    private static func validatePresentations(
        _ values: [ExperienceEntityPresentation],
        expectedIDs: Set<String>,
        kind: String,
        defaultLocale: String,
        requiresCompletionCopy: Bool
    ) throws {
        try requireUnique(values.map(\.id), kind: kind)
        guard Set(values.map(\.id)) == expectedIDs else {
            throw PlayableExperienceValidationError.coverageMismatch(kind: kind)
        }
        for value in values {
            guard !value.id.isEmpty else {
                throw PlayableExperienceValidationError.invalidField("\(kind) ID")
            }
            try validate(value.title, defaultLocale: defaultLocale)
            try value.subtitle.map { try validate($0, defaultLocale: defaultLocale) }
            try value.body.map { try validate($0, defaultLocale: defaultLocale) }
            if requiresCompletionCopy {
                guard let completionTitle = value.completionTitle,
                      let completionBody = value.completionBody else {
                    throw PlayableExperienceValidationError.invalidField(
                        "\(kind) \(value.id) completion copy"
                    )
                }
                try validate(completionTitle, defaultLocale: defaultLocale)
                try validate(completionBody, defaultLocale: defaultLocale)
            }
        }
    }

    private static func validate(
        _ value: LocalizedText,
        defaultLocale: String
    ) throws {
        guard !value.values.isEmpty,
              value.values.keys.allSatisfy({ !$0.isEmpty }),
              value.values.values.allSatisfy({ !$0.isEmpty }),
              value.values[defaultLocale] != nil else {
            throw PlayableExperienceValidationError.invalidField(
                "localized text must contain nonempty default locale \(defaultLocale)"
            )
        }
    }

    private static func requireUnique<T: Hashable>(
        _ values: [T],
        kind: String
    ) throws {
        guard Set(values).count == values.count else {
            let duplicate = values.first { candidate in
                values.filter { $0 == candidate }.count > 1
            }
            let duplicateDescription = duplicate.map { String(describing: $0) } ?? "unknown"
            throw PlayableExperienceValidationError.duplicate(
                kind: kind,
                id: duplicateDescription
            )
        }
    }
}
