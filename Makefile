# See the documentation on how to run the tests.

export DAV_SERVER := skip
export REMOTESTORAGE_SERVER := skip
export RADICALE_BACKEND := filesystem
export REQUIREMENTS := release
export TESTSERVER_BASE := ./tests/storage/servers/
export CI := false
export DETERMINISTIC_TESTS := false

install-servers:
	set -ex; \
	for server in $(DAV_SERVER) $(REMOTESTORAGE_SERVER); do \
		if [ ! -d "$(TESTSERVER_BASE)$$server/" ]; then \
			git clone --depth=1 \
				https://github.com/vdirsyncer/$$server-testserver.git \
				/tmp/$$server-testserver; \
			ln -s /tmp/$$server-testserver $(TESTSERVER_BASE)$$server; \
		fi; \
		(cd $(TESTSERVER_BASE)$$server && sh install.sh); \
	done

install-test: install-servers
	(python --version | grep -vq 'Python 3.3') || pip install enum34
	pip install -r test-requirements.txt
	set -xe && if [ "$$REQUIREMENTS" = "devel" ]; then \
		pip install -U --force-reinstall \
			git+https://github.com/DRMacIver/hypothesis \
			git+https://github.com/pytest-dev/pytest; \
	fi
	[ $(CI) != "true" ] || pip install coverage codecov

test:
	set -e; \
	if [ "$(CI)" = "true" ]; then \
		coverage run --source=vdirsyncer/ --module pytest; \
		codecov; \
	else \
		py.test; \
	fi

install-style:
	pip install flake8 flake8-import-order sphinx
	
style:
	flake8
	! grep -ri syncroniz */*
	sphinx-build -W -b html ./docs/ ./docs/_build/html/
	python3 scripts/make_travisconf.py | \
		diff -q .travis.yml - > /dev/null || \
		(echo 'travis.yml is outdated. Run `make travis-conf`.' && false)

travis-conf:
	python3 scripts/make_travisconf.py > .travis.yml

install-docs:
	pip install -r docs-requirements.txt

docs:
	cd docs && make html

sh:  # open subshell with default test config
	$$SHELL;

linkcheck:
	sphinx-build -W -b linkcheck ./docs/ ./docs/_build/linkcheck/

all:
	$(error Take a look at https://vdirsyncer.readthedocs.org/en/stable/tutorial.html#installation)

release:
	python setup.py sdist bdist_wheel upload

install-dev:
	set -xe && if [ "$$REMOTESTORAGE_SERVER" != "skip" ]; then \
		pip install -e .[remotestorage]; \
	else \
		pip install -e .; \
	fi
	set -xe && if [ "$$REQUIREMENTS" = "devel" ]; then \
	    pip install -U --force-reinstall \
			git+https://github.com/mitsuhiko/click \
			git+https://github.com/kennethreitz/requests; \
	elif [ "$$REQUIREMENTS" = "minimal" ]; then \
		pip install -U --force-reinstall $$(python setup.py --quiet minimal_requirements); \
	fi

.PHONY: docs
