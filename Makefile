SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL: build

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
IMAGE_TAG ?= azure-local

.PHONY: help build build-dbt build-airflow build-superset smoke

help:
	@echo "NYC Taxi Azure images (no service startup or cloud provisioning)"
	@echo "  make build [IMAGE_TAG=azure-local]"
	@echo "  make build-airflow | build-dbt | build-superset"
	@echo "  make smoke [IMAGE_TAG=azure-local]"

build: build-dbt build-airflow build-superset

build-dbt:
	docker build --file $(ROOT)/src/dbt/dockerfile --tag nyc-taxi-dbt:$(IMAGE_TAG) $(ROOT)

build-airflow:
	docker build --file $(ROOT)/src/airflow/dockerfile --tag nyc-taxi-airflow:$(IMAGE_TAG) $(ROOT)

build-superset:
	docker build --file $(ROOT)/src/superset/dockerfile --tag nyc-taxi-superset:$(IMAGE_TAG) $(ROOT)

smoke:
	@IMAGE_TAG="$(IMAGE_TAG)" $(ROOT)/scripts/smoke.sh
