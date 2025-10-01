.PHONY: run open

HOST ?= 127.0.0.1
PORT ?= 8000
URL := http://$(HOST):$(PORT)

run:
	python3 server.py --host $(HOST) --port $(PORT)

open:
	@echo "Opening $(URL)"
	@if [ "$(shell uname)" = "Darwin" ]; then \
		open "$(URL)"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$(URL)"; \
	elif command -v gio >/dev/null 2>&1; then \
		gio open "$(URL)"; \
	elif command -v gnome-open >/dev/null 2>&1; then \
		gnome-open "$(URL)"; \
	else \
		echo "No suitable opener found" >&2; \
	fi
