.PHONY: check lint test install

check: lint test

lint:
	shellcheck -x bin/workspaces install.sh scripts/install.sh assets/build.sh

test:
	bats -r test

install:
	./install.sh
