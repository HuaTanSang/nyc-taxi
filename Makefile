SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL: bootstrap

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV_FILE := $(ROOT)/.env

-include $(ENV_FILE)

PROJECT_PREFIX ?= nyc_taxi
FORCE ?= 0
export FORCE

COMPOSE := docker compose --env-file $(ENV_FILE)
MINIO := $(COMPOSE) --project-name $(PROJECT_PREFIX)_minio --project-directory $(ROOT)/src/minio --file $(ROOT)/src/minio/docker-compose.yaml
CLICKHOUSE := $(COMPOSE) --project-name $(PROJECT_PREFIX)_clickhouse --project-directory $(ROOT)/src/clickhouse --file $(ROOT)/src/clickhouse/docker-compose.yaml
AIRFLOW := $(COMPOSE) --project-name $(PROJECT_PREFIX)_airflow --project-directory $(ROOT)/src/airflow --file $(ROOT)/src/airflow/docker-compose.yaml
DBT := $(COMPOSE) --project-name $(PROJECT_PREFIX)_dbt --project-directory $(ROOT)/src/dbt --file $(ROOT)/src/dbt/docker-compose.yaml
SUPERSET := $(COMPOSE) --project-name $(PROJECT_PREFIX)_superset --project-directory $(ROOT)/src/superset --file $(ROOT)/src/superset/docker-compose.yaml

.PHONY: help check-tools configure require-env network build up-core seed-reference \
	bootstrap-airflow bootstrap-superset bootstrap up up-runtime down status logs doctor smoke

help:
	@echo "NYC Taxi local development"
	@echo "  make configure"
	@echo "  make bootstrap"
	@echo "  make up"
	@echo "  make doctor"
	@echo "  make smoke"
	@echo "  make logs STACK=airflow [SERVICE=airflow-scheduler]"
	@echo "  make down"

check-tools:
	@command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
	@docker info >/dev/null || { echo "Docker daemon is not available" >&2; exit 1; }
	@docker compose version >/dev/null || { echo "Docker Compose v2 is required" >&2; exit 1; }
	@command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
	@command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
	@memory_bytes="$$(docker info --format '{{.MemTotal}}')"; \
	minimum_bytes=6442450944; \
	if [ "$$memory_bytes" -lt "$$minimum_bytes" ]; then \
		echo "Docker must have at least 6 GiB of memory" >&2; \
		exit 1; \
	fi

configure:
	@$(ROOT)/scripts/configure.sh

require-env:
	@test -f $(ENV_FILE) || { echo "Run 'make configure' first" >&2; exit 1; }

network:
	@if docker network inspect platform_net >/dev/null 2>&1; then \
		echo "Network already exists: platform_net"; \
	else \
		docker network create platform_net; \
	fi

build: require-env
	@$(MINIO) build
	@$(CLICKHOUSE) build
	@$(AIRFLOW) build
	@$(DBT) build
	@$(SUPERSET) build

up-core: require-env network
	@$(MINIO) up -d --wait minio
	@$(CLICKHOUSE) up -d --wait clickhouse

seed-reference: require-env network
	@$(MINIO) --profile bootstrap run --rm minio-seed

bootstrap-airflow: require-env network
	@$(AIRFLOW) up -d --wait postgres
	@$(AIRFLOW) run --rm --no-deps airflow-permissions
	@$(AIRFLOW) run --rm --no-deps airflow-init

bootstrap-superset: require-env network
	@$(SUPERSET) up -d --wait superset-db
	@$(SUPERSET) run --rm --no-deps superset-init

bootstrap: check-tools require-env network build up-core bootstrap-airflow seed-reference bootstrap-superset up-runtime doctor

up: up-core up-runtime

up-runtime: require-env
	@$(AIRFLOW) up -d --wait airflow-apiserver airflow-scheduler airflow-dag-processor airflow-triggerer
	@$(SUPERSET) up -d --wait superset
	@$(DBT) up -d --wait dbt

down: require-env
	@$(DBT) down --remove-orphans
	@$(SUPERSET) down --remove-orphans
	@$(AIRFLOW) down --remove-orphans
	@$(CLICKHOUSE) down --remove-orphans
	@$(MINIO) down --remove-orphans

status: require-env
	@$(MINIO) ps
	@$(CLICKHOUSE) ps
	@$(AIRFLOW) ps
	@$(DBT) ps
	@$(SUPERSET) ps

logs: require-env
	@if [ -n "$(SERVICE)" ]; then \
		case "$(STACK):$(SERVICE)" in \
			minio:minio|minio:minio-seed|clickhouse:clickhouse|airflow:postgres|airflow:airflow-permissions|airflow:airflow-init|airflow:airflow-apiserver|airflow:airflow-scheduler|airflow:airflow-dag-processor|airflow:airflow-triggerer|dbt:dbt|superset:superset-db|superset:superset-init|superset:superset) ;; \
			*) echo "Invalid SERVICE for STACK=$(STACK): $(SERVICE)" >&2; exit 1 ;; \
		esac; \
	fi
	@case "$(STACK)" in \
		minio) command='$(MINIO)' ;; \
		clickhouse) command='$(CLICKHOUSE)' ;; \
		airflow) command='$(AIRFLOW)' ;; \
		dbt) command='$(DBT)' ;; \
		superset) command='$(SUPERSET)' ;; \
		*) echo "STACK must be one of: minio clickhouse airflow dbt superset" >&2; exit 1 ;; \
	esac; \
	if [ -n "$(SERVICE)" ]; then \
		$$command logs --follow "$(SERVICE)"; \
	else \
		$$command logs --follow; \
	fi

doctor: require-env
	@docker info >/dev/null || { echo "Docker daemon is not available" >&2; exit 1; }
	@docker network inspect platform_net >/dev/null 2>&1 || { echo "Missing Docker network: platform_net" >&2; exit 1; }
	@check_container() { \
		service="$$1"; \
		container_id="$$2"; \
		if [ -z "$$container_id" ]; then \
			echo "Service is not running: $$service" >&2; \
			exit 1; \
		fi; \
		state="$$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$$container_id")"; \
		case "$$state" in \
			healthy|running) ;; \
			*) echo "Service $$service is $$state" >&2; exit 1 ;; \
		esac; \
	}; \
	check_container minio "$$($(MINIO) ps -q minio)"; \
	check_container clickhouse "$$($(CLICKHOUSE) ps -q clickhouse)"; \
	for service in postgres airflow-apiserver airflow-scheduler airflow-dag-processor airflow-triggerer; do \
		check_container "$$service" "$$($(AIRFLOW) ps -q "$$service")"; \
	done; \
	for service in superset-db superset; do \
		check_container "$$service" "$$($(SUPERSET) ps -q "$$service")"; \
	done; \
	check_container dbt "$$($(DBT) ps -q dbt)"; \
	echo "Docker network and runtime services are healthy."

smoke: require-env
	@$(ROOT)/scripts/smoke.sh
