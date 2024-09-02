
IN_VENV=. venv/bin/activate

# create venv
venv:
	python3 -m venv venv
	$(IN_VENV) ; pip install -U pip setuptools wheel

# install dependencies
.PHONY: deps
deps: venv/deps
venv/deps: venv requirements.txt
	$(IN_VENV) ; pip install -Ur requirements.txt
	@touch $(@)


# cleanup everything including venv
.PHONY: clean
clean:
	rm -rf venv
	rm -rf .mypy_cache
	find . -ignore_readdir_race -type d -name __pycache__ -exec rm -rf {} \; 2>/dev/null || true
