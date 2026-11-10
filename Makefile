# Phase 1 lab workflow. Apply and destroy run against envs/lab only.
# `make` prints targets and does not create infrastructure.

SHELL       := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ENV_DIR := envs/lab
TF      := terraform -chdir=$(ENV_DIR)

.PHONY: help init init-backendless fmt fmt-check validate test plan up destroy lint lint-tflint lint-checkov

help: ## Show targets
	@printf '%s\n' \
		'up         Create or update the lab (Transit Gateway attachments bill hourly)' \
		'plan       Show the Terraform plan for envs/lab' \
		'destroy    Destroy the lab state (this is what stops the hourly charge)' \
		'fmt        Rewrite Terraform files with terraform fmt' \
		'validate   init -backend=false and terraform validate (no AWS credentials)' \
		'test       Mocked terraform test for the CIDR plan (no AWS credentials)' \
		'lint       fmt -check, validate, test, tflint, and checkov'

init: ## terraform init for apply, plan, and destroy
	$(TF) init -input=false

init-backendless: ## terraform init without configuring a backend
	$(TF) init -backend=false -input=false -lockfile=readonly

fmt: ## terraform fmt -recursive
	terraform fmt -recursive

fmt-check: ## Fail if terraform fmt would change a file
	terraform fmt -recursive -check -diff

validate: init-backendless ## Validate the lab configuration
	$(TF) validate

test: init-backendless ## Plan the lab with the AWS provider mocked
	$(TF) test

plan: init ## terraform plan
	$(TF) plan -input=false

up: ## Apply envs/lab
	./scripts/up.sh

destroy: ## Destroy envs/lab without a prompt
	./scripts/destroy.sh --yes

lint-tflint: ## Run tflint with the repo config
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	tflint --recursive --config "$(CURDIR)/.tflint.hcl" --format compact

lint-checkov: ## Run checkov against the Terraform configuration
	checkov -d "$(CURDIR)" --framework terraform --compact --download-external-modules false

lint: fmt-check validate test lint-tflint lint-checkov ## Run the same checks CI runs
