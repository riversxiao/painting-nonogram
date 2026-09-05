.PHONY: build build-app-host validate-app-host validate-fixture validate-session validate-board-input validate-progress validate-access validate-product validate-experience validate-app

APP_HOST_DERIVED_DATA := .build/xcode
APP_HOST_PRODUCT := $(APP_HOST_DERIVED_DATA)/Build/Products/Debug-iphonesimulator/KanakaApp.app

build:
	swift build --package-path Packages/KanakaCore
	swift build --package-path Packages/KanakaContentKit
	swift build --package-path Packages/KanakaProgress
	swift build --package-path Packages/KanakaStory
	swift build --package-path Packages/KanakaProductDomain
	swift build --package-path Tools/kanaka-content
	swift build --package-path Apps/KanakaApp

build-app-host:
	@command -v xcodebuild >/dev/null 2>&1 || { echo "error: build-app-host requires macOS with Xcode 16 or newer"; exit 1; }
	@version="$$(xcodebuild -version | awk 'NR == 1 { print $$2 }')"; major="$${version%%.*}"; \
		case "$$major" in ''|*[!0-9]*) echo "error: unable to determine Xcode version"; exit 1;; esac; \
		[ "$$major" -ge 16 ] || { echo "error: build-app-host requires Xcode 16 or newer (found Xcode $$version)"; exit 1; }
	xcodebuild -project Apps/KanakaApp/KanakaApp.xcodeproj -scheme KanakaApp -destination 'generic/platform=iOS Simulator' -derivedDataPath $(APP_HOST_DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build

validate-app-host: build-app-host
	@test -d "$(APP_HOST_PRODUCT)" || { echo "error: missing App bundle at $(APP_HOST_PRODUCT)"; exit 1; }
	@test -x "$(APP_HOST_PRODUCT)/KanakaApp" || { echo "error: missing linked KanakaApp executable"; exit 1; }
	swift Tools/validate-apple-host.swift "$(APP_HOST_PRODUCT)" "$(APP_HOST_DERIVED_DATA)"
	swift run --package-path Tools/kanaka-content kanaka-content validate-content "$(APP_HOST_PRODUCT)/Content"
	swift run --package-path Tools/kanaka-content kanaka-content validate-playable-experience "$(APP_HOST_PRODUCT)/Content"
	@echo "KanakaApp Apple Host and Bundle contract validated"

validate-fixture:
	swift run --package-path Tools/kanaka-content kanaka-content validate-content Content/Fixtures

validate-session:
	swift run --package-path Tools/kanaka-content kanaka-content validate-session Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-board-input:
	swift run --package-path Tools/kanaka-content kanaka-content validate-board-input Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-progress:
	swift run --package-path Tools/kanaka-content kanaka-content validate-progress Content/Fixtures/m1-g1-a01-f01/puzzle-definition.json

validate-access:
	swift run --package-path Tools/kanaka-content kanaka-content validate-access Content/Fixtures/artworks/cardinality-4/artwork.json

validate-product:
	swift run --package-path Tools/kanaka-content kanaka-content validate-product-flow Content/Fixtures

validate-experience:
	swift run --package-path Tools/kanaka-content kanaka-content validate-playable-experience Content/Fixtures

validate-app:
	swift run --package-path Tools/kanaka-content kanaka-content validate-content Apps/KanakaApp/Sources/KanakaApp/Resources/Content
	swift run --package-path Tools/kanaka-content kanaka-content validate-playable-experience Apps/KanakaApp/Sources/KanakaApp/Resources/Content
	swift run --package-path Apps/KanakaApp KanakaApp
