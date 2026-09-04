#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaContentKit

func experienceText(
    _ value: LocalizedText,
    catalog: RuntimeContentCatalog
) -> String {
    catalog.experience.text(
        value,
        preferredLocales: Locale.preferredLanguages
    )
}

func experienceTitle(
    _ presentation: ExperienceEntityPresentation?,
    fallbackID: String,
    catalog: RuntimeContentCatalog
) -> String {
    guard let presentation else { return displayName(fallbackID) }
    return experienceText(presentation.title, catalog: catalog)
}
#endif
