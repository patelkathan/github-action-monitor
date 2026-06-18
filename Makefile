.PHONY: build release bundle dmg run clean icon test-build

build:
	swift build

release:
	swift build -c release

icon:
	swift scripts/make-icon.swift

bundle: icon
	./scripts/package.sh

dmg: bundle
	./scripts/make-dmg.sh

run: bundle
	open TrayFlow.app

clean:
	rm -rf .build TrayFlow.app TrayFlow.zip TrayFlow.dmg .dmg-staging Resources/AppIcon.iconset

# Quick typecheck without producing a binary (used in CI for fast feedback).
test-build:
	swift build
