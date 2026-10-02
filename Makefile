# OrbTorrent build entry points.
#
#   make engine         Build qbittorrent-nox for this Mac's architecture
#   make extensions     Build the extension SDK and the official extensions (needs Node.js 22+)
#   make sparkle        Download Sparkle, the updater, and its tools into build/sparkle
#   make test-extensions  Test the extension SDK, the official extensions and their scripts
#   make dev            Build OrbTorrent Dev, quit the running copy and open the new one
#   make run            Build OrbTorrent.app and open it
#   make install        Build OrbTorrent.app, and replace and reopen the one in /Applications
#   make test           Run the unit tests (TESTS="-only-testing:OrbTorrentTests/UpdatesTests" for some)
#   make dmg            Build OrbTorrent.app and package build/OrbTorrent-<version>.dmg
#   make release        Universal (Apple silicon + Intel) engine, app and DMG
#
# OrbTorrent Dev is the app used while developing OrbTorrent: its own bundle
# identifier, library, settings and amber icon, so it runs beside OrbTorrent.
#
# Builds are signed with the first matching certificate in the Keychain: for
# OrbTorrent a "Developer ID Application" one, else "Apple Development"; for
# OrbTorrent Dev "Apple Development". With none, as on CI, they're signed ad
# hoc. A certificate keeps the app's identity the same from build to build, so
# macOS doesn't ask for permissions or Keychain access again after each one.
# Set SIGN_IDENTITY to choose, and NOTARY_PROFILE=<notarytool keychain profile>
# to notarize the DMG.

ARCHS ?= $(shell uname -m)
CONFIG ?= Release
identity = $(shell security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\($(1): [^"]*\)".*/\1/p' | head -1)
SIGN_IDENTITY ?= $(or $(call identity,Developer ID Application),$(call identity,Apple Development),-)
DEV_SIGN_IDENTITY ?= $(or $(call identity,Apple Development),-)
BUILD_DIR := build
DERIVED := $(BUILD_DIR)/DerivedData
APP := $(BUILD_DIR)/OrbTorrent.app
DEV_APP := $(BUILD_DIR)/OrbTorrent Dev.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: engine extensions sparkle test-extensions project app dev test run dmg install release clean

engine:
	ARCHS="$(ARCHS)" ./engine/build.sh

extensions:
	npm ci --no-audit --no-fund
	npm run build --workspace sdk
	for extension in extensions/*/; do (cd "$$extension" && npx orb build) || exit 1; done

test-extensions: extensions
	npm test --workspace sdk
	for extension in extensions/*/; do (cd "$$extension" && npx orb test && npx orb lint) || exit 1; done
	node --test "scripts/*.test.mjs"
	node scripts/extension-docs.mjs --check

sparkle:
	@./scripts/fetch-sparkle.sh >/dev/null

project: sparkle
	xcodegen generate --quiet

app: project extensions
	xcodebuild -project OrbTorrent.xcodeproj -scheme OrbTorrent -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -quiet \
		ARCHS="$(ARCHS)" ONLY_ACTIVE_ARCH=NO \
		CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" \
		$(if $(findstring Developer ID,$(SIGN_IDENTITY)),OTHER_CODE_SIGN_FLAGS=--timestamp) \
		build
	rm -rf $(APP)
	cp -R $(DERIVED)/Build/Products/$(CONFIG)/OrbTorrent.app $(APP)
	@# Only the installed copy should open magnet links and .torrent files.
	@$(LSREGISTER) -u $(DERIVED)/Build/Products/$(CONFIG)/OrbTorrent.app $(APP) 2>/dev/null || true
	@echo "Built $(APP), signed by $(SIGN_IDENTITY)"

dev: project extensions
	xcodebuild -project OrbTorrent.xcodeproj -scheme OrbTorrent -configuration Dev \
		-derivedDataPath $(DERIVED) -quiet \
		CODE_SIGN_IDENTITY="$(DEV_SIGN_IDENTITY)" \
		build
	osascript -e 'quit app "OrbTorrent Dev"' 2>/dev/null || true
	@for i in $$(seq 1 60); do pgrep -xq "OrbTorrent Dev" || break; sleep 0.5; done
	@if pgrep -xq "OrbTorrent Dev"; then echo "error: OrbTorrent Dev didn't quit; close any open sheet and run make dev again."; exit 1; fi
	rm -rf "$(DEV_APP)"
	cp -R "$(DERIVED)/Build/Products/Dev/OrbTorrent Dev.app" "$(DEV_APP)"
	open "$(DEV_APP)"
	@echo "Opened $(DEV_APP), signed by $(DEV_SIGN_IDENTITY)"

# Signed like OrbTorrent Dev, so the Desktop access the tests need to read the
# repo's fixtures is asked for once, not after every build.
test: project extensions
	xcodebuild -project OrbTorrent.xcodeproj -scheme OrbTorrent -configuration Debug \
		-derivedDataPath $(DERIVED) -quiet \
		CODE_SIGN_IDENTITY="$(DEV_SIGN_IDENTITY)" \
		test $(TESTS)

run: app
	open $(APP)

dmg: app
	./scripts/make-dmg.sh $(APP) $(BUILD_DIR)

install: app
	osascript -e 'quit app id "com.orbtorrent.mac"' 2>/dev/null || true
	@for i in $$(seq 1 60); do pgrep -xq OrbTorrent || break; sleep 0.5; done
	@if pgrep -xq OrbTorrent; then echo "error: OrbTorrent didn't quit; close any open sheet and run make install again."; exit 1; fi
	rm -rf /Applications/OrbTorrent.app
	cp -R $(APP) /Applications/OrbTorrent.app
	open /Applications/OrbTorrent.app
	@echo "Installed and opened /Applications/OrbTorrent.app"

release:
	$(MAKE) engine ARCHS="arm64 x86_64"
	$(MAKE) dmg ARCHS="arm64 x86_64"

clean:
	rm -rf $(BUILD_DIR) OrbTorrent.xcodeproj node_modules sdk/dist extensions/*/dist
