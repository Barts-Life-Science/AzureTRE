# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Azure Trusted Research Environment (Azure TRE) is an infrastructure accelerator that deploys secure, isolated workspaces on Azure for research teams working with sensitive data. It uses a multi-service architecture: a FastAPI-based REST API, an async resource processor (VMSS) that runs Porter/CNAB bundles, and an airlock processor (Azure Functions) for data import/export.

## Common Commands

All top-level operations are driven by `make`. Run `make help` to see available targets.

### Linting
```bash
make lint                # Lint everything (runs Super-Linter in Docker)
make lint-docs           # Lint only docs and mkdocs.yml
```

### Building Images
```bash
make build-api-image
make build-resource-processor-vm-porter-image
make build-airlock-processor
make images              # Build and push all images
```

### Unit Tests (run inside Docker)
Unit tests are baked into the Dockerfile test stage. To run them locally, build the test stage:
```bash
cd api_app && docker build --target test -f Dockerfile .
cd resource_processor && docker build --target test -f vmss_porter/Dockerfile .
cd airlock_processor && docker build --target test -f Dockerfile .
```

### E2E Tests (require a deployed TRE environment)
```bash
make test-e2e-smoke
make test-e2e-extended
make test-e2e-shared-services
# Single test:
cd e2e_tests && python -m pytest -m smoke -k "test_name" --verify true
```

### Porter Bundle Operations
```bash
make workspace_bundle BUNDLE=base
make workspace_service_bundle BUNDLE=guacamole
make shared_service_bundle BUNDLE=firewall
make user_resource_bundle WORKSPACE_SERVICE=guacamole BUNDLE=guacamole-azure-windowsvm
make bundle-publish-register-all   # Publish and register all bundles
```

### Infrastructure
```bash
make bootstrap           # Init Terraform backend
make mgmt-deploy         # Deploy CI/CD management infra (ACR, storage)
make deploy-core         # Deploy TRE core Azure resources
make tre-deploy          # Full deploy: core + UI + firewall + DB migration
make tre-destroy         # Destroy TRE
```

### Environment Setup
Copy `.env.sample` to `.env` in the relevant directory (`api_app/`, `e2e_tests/`, or a template folder) and fill in values. The Makefile loads env via `devops/scripts/load_and_validate_env.sh`.

## Architecture

### Service Breakdown

| Service | Language | Directory | Purpose |
|---------|----------|-----------|---------|
| API | Python/FastAPI | `api_app/` | REST API; manages workspaces, bundles, operations, airlock |
| Resource Processor | Python | `resource_processor/` | Reads Service Bus queue; invokes Porter to deploy bundles |
| Airlock Processor | Python/Azure Functions | `airlock_processor/` | Handles blob import/export, scanning triggers |
| CLI | Python/Click | `cli/` | TRE admin CLI wrapper around the REST API |
| UI | React | `ui/app/` | Web frontend |

### Deployment Flow

1. User/API puts a deployment message on **Azure Service Bus**
2. **Resource Processor** (running on VMSS) picks up the message and runs `porter install/upgrade/uninstall`
3. Porter executes Terraform from the bundle, targeting the workspace's Azure subscription/resource group
4. Status updates are sent back to Service Bus → API updates CosmosDB (MongoDB API)

### Templates / Porter Bundles

Templates live in `templates/` and follow a strict hierarchy:
- `workspaces/` — top-level workspace bundles (e.g. `base`, `unrestricted`)
- `workspace_services/` — services within a workspace (e.g. `guacamole`, `azureml`, `gitea`)
- `workspace_services/<name>/user_resources/` — user-level resources within a service (e.g. VMs)
- `shared_services/` — TRE-wide shared services (e.g. `firewall`, `gitea`)

Each bundle has a `porter.yaml` (bundle definition), a `Dockerfile.tmpl`, and a `terraform/` subdirectory. Bundles expose `install`, `upgrade`, and `uninstall` actions that map to `terraform apply` / `terraform destroy`.

### Core Infrastructure

`core/terraform/` defines all central Azure resources: App Service (API), CosmosDB, Service Bus, Key Vault, Application Gateway, VMSS (resource processor), storage accounts, VNet, DNS zones. Terraform backend state is stored in Azure Storage.

`devops/terraform/` provisions the management-plane resources needed for CI/CD (container registry, state storage account).

### Key Configuration Pattern

Version numbers are stored in `_version.py` files per service (`api_app/_version.py`, `resource_processor/_version.py`, etc.). The Makefile sources these to tag Docker images. **Bump versions when changing code** — CI enforces this.

### Authentication

All services authenticate to Azure via Managed Identity in production. Local development uses service principal credentials via `arm_auth_local_debugging.json`. The API uses MSAL for validating Entra ID tokens from the UI/CLI.

## Testing Notes

- E2E tests use `pytest-asyncio` with `asyncio_mode = auto` and `httpx` for HTTP requests
- Test markers: `smoke`, `extended`, `extended_aad`, `shared_services`, `performance`, `airlock`, `workspace_services`
- Unit tests live in `tests_ma/` (api_app), `tests_rp/` (resource_processor), and `tests/` (airlock_processor)
- E2E tests require environment variables from `e2e_tests/.env` (copy from `.env.sample`)

## GitHub / Pull Requests

This repo is a fork of `microsoft/AzureTRE`. The remotes are:
- `origin` → `Barts-Life-Science/AzureTRE` (the fork)
- `upstream` → `microsoft/AzureTRE`

**NEVER open a PR against `microsoft/AzureTRE` (upstream) without first checking with the user.**
PRs against `Barts-Life-Science/AzureTRE` can be raised without asking.

The `gh` CLI resolves the base repo from the `upstream` remote by default. Always pass `--repo Barts-Life-Science/AzureTRE` explicitly when creating PRs to avoid accidentally targeting upstream.

## Development Container

The devcontainer (`.devcontainer/`) includes VS Code launch configurations for debugging the API locally (uvicorn on port 8000 with auto-reload) and for running individual E2E test suites. It mounts the Docker socket so you can build images from within the container.
