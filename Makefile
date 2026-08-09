.PHONY: check lint test install menubar-build menubar-test

check: lint test

lint:
	shellcheck -x bin/workframe install.sh lib/*.sh contrib/mount-workframe.sh assets/build.sh

test:
	bats -r test

install:
	./install.sh

menubar-build:
	./scripts/build-menubar-app.sh

menubar-test:
	swift test
