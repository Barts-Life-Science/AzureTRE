#!/bin/bash
# ---------------------------------------------------------------------------
# deploy-archive-refactor.sh
#
# End-to-end runner for the "fold blob-storage into base workspace" refactor.
#   • Publishes the three updated bundles to ACR (auto)
#   • Verifies the new versions appear in the registry (auto)
#   • Pauses for the four TRE UI clicks (manual; instructions printed)
#   • Prints the smoke-test commands to paste on the workspace VM (manual)
#
# Run from the repo root:
#     ./deploy-archive-refactor.sh
# ---------------------------------------------------------------------------
set -o errexit
set -o pipefail
set -o nounset

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

BASE_VER=2.1.0
LINUX_VER=1.2.15
WIN_VER=1.2.14

# Discoverable from core/private.env or fall back to known value for this TRE
TRE_ID="${TRE_ID:-devtre02}"
WS_SUFFIX="${WS_SUFFIX:-270e}"

banner() { printf "\n\033[1;36m=== %s ===\033[0m\n" "$*"; }

# ---------------------------------------------------------------------------
banner "Phase 1 — publish updated bundles to ACR"
# ---------------------------------------------------------------------------
echo "Publishing base workspace ${BASE_VER}, linuxvm ${LINUX_VER}, windowsvm ${WIN_VER}..."

make workspace_bundle BUNDLE=base
make user_resource_bundle WORKSPACE_SERVICE=guacamole BUNDLE=guacamole-azure-linuxvm
make user_resource_bundle WORKSPACE_SERVICE=guacamole BUNDLE=guacamole-azure-windowsvm

# ---------------------------------------------------------------------------
banner "Phase 1 verification — confirm new tags are in ACR"
# ---------------------------------------------------------------------------
# Resolve ACR_NAME in this order: env var, core/private.env, config.yaml.
if [[ -z "${ACR_NAME:-}" && -f core/private.env ]]; then
  # shellcheck disable=SC1091
  set +o nounset; source core/private.env; set -o nounset
fi
if [[ -z "${ACR_NAME:-}" && -f config.yaml ]] && command -v yq >/dev/null 2>&1; then
  ACR_NAME="$(yq '.management.acr_name // .acr_name' config.yaml | tr -d '"' | sed '/^null$/d')"
fi
: "${ACR_NAME:?ACR_NAME not resolved from env, core/private.env, or config.yaml}"

echo "Latest tags in ACR ($ACR_NAME):"
for repo in \
    tre-workspace-base \
    tre-service-guacamole-linuxvm \
    tre-service-guacamole-windowsvm; do
  printf "  %-40s -> " "$repo"
  az acr repository show-tags --name "$ACR_NAME" --repository "$repo" \
     --orderby time_desc --top 1 -o tsv | head -1
done

cat <<EOF

Expected most-recent tags:
  tre-workspace-base                       -> v${BASE_VER}
  tre-service-guacamole-linuxvm            -> v${LINUX_VER}
  tre-service-guacamole-windowsvm          -> v${WIN_VER}
EOF

# ---------------------------------------------------------------------------
banner "Next steps — TRE UI + smoke test (manual, no more script needed)"
# ---------------------------------------------------------------------------
cat <<EOF

Bundles are now published to ACR. Finish the rollout with these steps in the
TRE UI for workspace ${WS_SUFFIX}, then smoke-test on the VM.

------------------------------------------------------------
Step A — decommission the old standalone Blob Storage service
------------------------------------------------------------
  Workspace Services -> Blob Storage -> ⋮ -> Disable -> (wait ~1-2 min) ->
  ⋮ -> Delete -> confirm.

  This tears down stgblobsvc<random>, its private endpoint, and the role
  assignment we put on it earlier today. The 'demo.txt' blob goes with it.

------------------------------------------------------------
Step B — upgrade the workspace 2.0.3 -> ${BASE_VER}
------------------------------------------------------------
  Workspace -> Properties (or Workspace -> ⋮) -> Upgrade -> pick ${BASE_VER}
  -> Submit. Wait ~3-5 min.

  Adds the 'archive' container + lifecycle policy to the existing workspace
  shared storage account. Existing VMs and the shared file share keep
  running through the upgrade.

------------------------------------------------------------
Step C — upgrade existing VMs (one per VM)
------------------------------------------------------------
  Linux VM (linuxvmd4e0):
    Guacamole -> linuxvmd4e0 -> ⋮ -> Upgrade -> pick ${LINUX_VER}.

  Windows VM (if you have one):
    Guacamole -> <windows-vm-name> -> ⋮ -> Upgrade -> pick ${WIN_VER}.

  Each upgrade adds the role assignment that grants the VM's managed
  identity 'Storage Blob Data Contributor' on the workspace shared SA.
  VMs are NOT recreated; no reboot.

------------------------------------------------------------
Step D — smoke test (on the workspace VM, not here)
------------------------------------------------------------
Open Guacamole -> connect to linuxvmd4e0 -> terminal, then paste:

  SA=stg<your-workspace-suffix>     # from workspace Outputs in the TRE UI
  CONT=archive

  az login --identity
  az account show --query "user.name" -o tsv      # expect: systemAssignedIdentity

  nslookup \$SA.blob.core.windows.net | grep -E "privatelink|Address"

  echo "hello \$(date)" > /tmp/x
  az storage blob upload   --account-name \$SA --container-name \$CONT --auth-mode login --name x --file /tmp/x
  az storage blob list     --account-name \$SA --container-name \$CONT --auth-mode login -o table
  az storage blob download --account-name \$SA --container-name \$CONT --auth-mode login --name x --file /tmp/x-out
  diff /tmp/x /tmp/x-out && echo "round-trip OK"

When you see 'round-trip OK', the refactor is fully verified.
EOF

banner "Bundle publishes complete. ✅  Now do steps A-D above."
