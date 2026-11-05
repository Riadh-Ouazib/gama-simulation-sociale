PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)

.PHONY: pdf figures

pdf:
	bash scripts/build_report.sh

figures:
	$(PYTHON) scripts/figures.py
