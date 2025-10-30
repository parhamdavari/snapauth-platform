SHELL := /bin/bash
COMPOSE ?= docker compose
SERVICE ?= snapauth
TAIL ?= 100
PORT ?= 8080
SNAPAUTH_IMAGE ?= ghcr.io/parhamdavari/snapauth:latest
BOOTSTRAP_IMAGE ?= ghcr.io/parhamdavari/snapauth-bootstrap:latest

.PHONY: help bootstrap up start stop restart logs ps shell health clean reset

help:
	@echo "Setup:"
	@echo "  make up                # bootstrap secrets and start stack"
	@echo "  SNAPAUTH_IMAGE=... BOOTSTRAP_IMAGE=... make up  # use custom tags"
	@echo
	@echo "Diagnostics:"
	@echo "  make logs SERVICE=snapauth  # tail service logs"
	@echo "  make ps                     # docker compose ps"
	@echo "  make shell SERVICE=snapauth # shell into container"
	@echo "  make health                 # call SnapAuth health endpoints"
	@echo
	@echo
	@echo "Cleanup:"
	@echo "  make stop        # docker compose down"
	@echo "  make clean       # docker compose down -v"
	@echo "  make reset       # clean + remove .env and kickstart"

bootstrap:
	docker run --rm -v $(PWD):/workspace $(BOOTSTRAP_IMAGE)

up: bootstrap
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) up -d

start:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) up -d

stop:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) down

restart: stop start

logs:
	$(COMPOSE) logs --tail $(TAIL) $(SERVICE)

ps:
	$(COMPOSE) ps

shell:
	$(COMPOSE) exec $(SERVICE) sh

health:
	curl --fail http://localhost:$(PORT)/health
	curl --fail http://localhost:$(PORT)/health/jwt-config

clean:
	SNAPAUTH_IMAGE=$(SNAPAUTH_IMAGE) BOOTSTRAP_IMAGE=$(BOOTSTRAP_IMAGE) $(COMPOSE) down -v --remove-orphans


reset: clean
	rm -f .env
	rm -rf kickstart

