.PHONY: build run test clean package icon help

VERSION := 0.1.0

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build release binary
	swift build -c release

debug: ## Build debug binary
	swift build

run: debug ## Build and run (debug)
	.build/debug/BrewManager

test: ## Run tests
	swift test

icon: ## Generate app icon
	swift Scripts/generate-icon.swift Resources
	mkdir -p Resources/AppIcon.iconset
	sips -z 16 16 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_16x16.png
	sips -z 32 32 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_16x16@2x.png
	sips -z 32 32 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_32x32.png
	sips -z 64 64 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_32x32@2x.png
	sips -z 128 128 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_128x128.png
	sips -z 256 256 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_128x128@2x.png
	sips -z 256 256 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_256x256.png
	sips -z 512 512 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_256x256@2x.png
	sips -z 512 512 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_512x512.png
	sips -z 1024 1024 Resources/AppIcon-1024.png --out Resources/AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
	rm -rf Resources/AppIcon.iconset

package: ## Build .app bundle + DMG
	chmod +x Scripts/package.sh
	Scripts/package.sh

clean: ## Remove build artifacts
	swift package clean
	rm -rf .build dist
