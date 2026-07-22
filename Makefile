.PHONY: check lint test install

check: lint test

lint:
	shellcheck -x bin/wt install.sh lib/*.sh

test:
	bats -r test

install:
	./install.sh
