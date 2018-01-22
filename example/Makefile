.PHONY: help

help: ## This help text
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

source: ## Create a new development environment
	cd src && rm -f composer.lock && composer install --no-progress

env: ## Setup a test environment
	docker-compose build
	docker-compose up

clean: ## Clean up
	docker-compose down
	find src -maxdepth 1 -type d ! -name 'src' ! -name 'app' -exec rm -rf {} \;
	find src -type f ! -name '.gitkeep' ! -name 'cron' ! -name 'composer.json' ! -name 'config.php' ! -name 'env.php' -exec rm -f {} \;
	rm -rf src/app/design/
	rm -rf mysql/*
