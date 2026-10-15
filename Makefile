.PHONY: help install serve build clean

help: ## Show help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install  Install documentation dependencies"
	@echo "  serve    Start local MkDocs preview server"
	@echo "  build    Build static documentation site to site/"
	@echo "  clean    Remove build output directory"

install: ## Install documentation dependencies
	pip install -r requirements.txt

serve: ## Start local MkDocs preview server
	mkdocs serve

build: ## Build static documentation site
	mkdocs build --strict

clean: ## Clean build artifacts
	rm -rf site/
