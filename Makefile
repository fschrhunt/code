.PHONY: check lint test install menubar-build menubar-test menubar-package menubar-release menubar-cask

check: lint test

lint:
	shellcheck -x bin/workframe install.sh lib/*.sh contrib/mount-workframe.sh assets/build.sh scripts/*.sh

test:
	bats -r test

install:
	./install.sh

menubar-build:
	./scripts/build-menubar-app.sh

menubar-test:
	swift test

menubar-package:
	./scripts/package-menubar-cask.sh

menubar-release:
	./scripts/release-menubar-cask.sh

menubar-cask:
	./scripts/write-homebrew-cask.sh "$(SHA256)"
