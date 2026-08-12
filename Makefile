.PHONY: check lint test install

check: lint test

lint:
	shellcheck -x bin/workframe install.sh scripts/install.sh lib/*.sh assets/build.sh

test:
	bats -r test

install:
	./install.sh
