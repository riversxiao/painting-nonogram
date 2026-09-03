.PHONY: build validate-fixture validate-session validate-progress

build:
	swift build --package-path Packages/KanakaCore
	swift build --package-path Packages/KanakaContentKit
	swift build --package-path Packages/KanakaProgress
	swift build --package-path Tools/kanaka-content

validate-fixture:
	swift run --package-path Tools/kanaka-content kanaka-content validate-content Content/Fixtures

validate-session:
	swift run --package-path Tools/kanaka-content kanaka-content validate-session Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-progress:
	swift run --package-path Tools/kanaka-content kanaka-content validate-progress Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json
