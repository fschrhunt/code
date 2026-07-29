.PHONY: check lint test install

check: lint test

lint:
	shellcheck -x bin/workframe install.sh lib/*.sh contrib/mount-workframe.sh

test:
	bats -r test

install:
	./install.sh
