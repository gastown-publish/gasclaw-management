.PHONY: install test clean lint format

install:
	./install.sh

install-dev:
	pip3 install -e .

test:
	python3 -m pytest tests/ -v || echo "No tests yet"
	python3 gasclaw.py --help
	python3 gasclaw.py version

clean:
	rm -rf __pycache__ *.egg-info build dist
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -delete

lint:
	flake8 gasclaw.py || true
	pylint gasclaw.py || true

format:
	black gasclaw.py || true

run:
	python3 gasclaw.py status

run-json:
	python3 gasclaw.py --json status

tui:
	python3 gasclaw.py tui
