.PHONY: build validate-fixture validate-session validate-progress validate-access validate-product

build:
	swift build --package-path Packages/KanakaCore
	swift build --package-path Packages/KanakaContentKit
	swift build --package-path Packages/KanakaProgress
	swift build --package-path Packages/KanakaStory
	swift build --package-path Packages/KanakaProductDomain
	swift build --package-path Tools/kanaka-content
	swift build --package-path Apps/KanakaApp

validate-fixture:
	swift run --package-path Tools/kanaka-content kanaka-content validate-content Content/Fixtures

validate-session:
	swift run --package-path Tools/kanaka-content kanaka-content validate-session Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-progress:
	swift run --package-path Tools/kanaka-content kanaka-content validate-progress Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-access:
	swift run --package-path Tools/kanaka-content kanaka-content validate-access Content/Fixtures/artworks/cardinality-4/artwork.json

validate-product:
	swift run --package-path Tools/kanaka-content kanaka-content validate-product-flow Content/Fixtures
