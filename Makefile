SHELL := /bin/bash
COMPOSE ?= docker compose
SERVICE ?= snapauth
TAIL ?= 100
PORT ?= 8080
MODE ?= isolated
SNAPAUTH_IMAGE ?= snapauth:v2.0.0
BOOTSTRAP_IMAGE ?= snapauth-bootstrap:v2.0.0

# Compose files based on MODE
ifeq ($(MODE),microservices)
	COMPOSE_FILES := -f docker-compose.yml -f docker-compose.microservices.yml
else
	COMPOSE_FILES := -f docker-compose.yml
endif

.PHONY: help bootstrap up start stop restart logs ps shell health clean reset backup restore

help:
	@echo "Setup:"
	@echo "  make up                        # bootstrap secrets and start stack (isolated mode)"
	@echo "  make up MODE=microservices     # start with shared-services integration"
	@echo "  SNAPAUTH_IMAGE=... BOOTSTRAP_IMAGE=... make up  # use custom tags"
	@echo
	@echo "Deployment Modes:"
	@echo "  MODE=isolated (default)        # isolated network, no external dependencies"
	@echo "  MODE=microservices             # join shared-services network"
	@echo
	@echo "Diagnostics:"
	@echo "  make logs SERVICE=snapauth     # tail service logs"
	@echo "  make ps                        # docker compose ps"
	@echo "  make shell SERVICE=snapauth    # shell into container"
	@echo "  make health                    # call SnapAuth health endpoints"
	@echo
	@echo "Operations:"
	@echo "  make backup                    # backup database and configuration"
	@echo "  make restore BACKUP_PATH=...   # restore from backup"
	@echo
	@echo "Cleanup:"
	@echo "  make stop                      # docker compose down"
	@echo "  make clean                     # docker compose down -v"
	@echo "  make reset                     # clean + remove .env and kickstart"

bootstrap:
	docker run --rm -v $(PWD):/workspace $(BOOTSTRAP_IMAGE)

up: bootstrap
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) $(COMPOSE_FILES) up -d

start:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) $(COMPOSE_FILES) up -d

stop:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) $(COMPOSE_FILES) down

restart: stop start

logs:
	$(COMPOSE) $(COMPOSE_FILES) logs --tail $(TAIL) $(SERVICE)

ps:
	$(COMPOSE) $(COMPOSE_FILES) ps

shell:
	$(COMPOSE) $(COMPOSE_FILES) exec $(SERVICE) sh

health:
	curl --fail http://localhost:$(PORT)/health
	curl --fail http://localhost:$(PORT)/health/jwt-config

clean:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) $(COMPOSE_FILES) down -v --remove-orphans

reset: clean
	rm -f .env
	rm -rf kickstart

backup:
	@bash scripts/backup.sh

restore:
	@bash scripts/restore.sh $(BACKUP_PATH)

