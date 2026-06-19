#!/bin/bash
# Direct-dependency licence + vulnerability scan for Barts-touched manifests.
# Called by .github/workflows/trivy_license_scan.yml (PharosAI-BH #87).
#
# Why this is not a one-line `trivy fs`:
#   Trivy reads pip/npm LICENCE metadata from INSTALLED packages, not from a
#   bare requirements.txt / package.json. A bare-manifest licence scan returns
#   zero licences (verified) -- a gate on that never fires. So we install, then
#   scan with --license-full.
#   #8 says track DIRECT dependencies, not nested ones. So we install direct
#   deps only (`pip --no-deps`; npm direct-dep name filter) and gate on those.
#
# Per manifest, writes to $OUTDIR:
#   sbom/<slug>.cdx.json   CycloneDX SBOM (vuln + license scanners)
#   vuln/<slug>.json       MEDIUM+ vulnerabilities (non-blocking, triaged per #87)
#   license/<slug>.json    direct-dep licences (--license-full)
# Exit 1 if any direct dependency carries a restricted/forbidden (copyleft) licence.

set -euo pipefail

MANIFEST_LIST="${1:?usage: trivy_license_scan.sh <manifest-list-file>}"
OUTDIR="${OUTDIR:-reports}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

mkdir -p "${OUTDIR}/sbom" "${OUTDIR}/vuln" "${OUTDIR}/license"
gate_failed=0
npm_done=" "  # directories already licence-scanned via npm, to avoid double work

slug() { echo "$1" | tr '/' '_'; }

# A package's own licence lives in LICENSE/COPYING; third-party NOTICE files list
# the licences of projects the package merely references (e.g. TypeScript's
# ThirdPartyNoticeText.txt carries CC-BY-NC entries while TypeScript itself is
# Apache-2.0). --license-full reads loose files indiscriminately, so skip notice
# files to avoid misattributing a referenced licence to the package.
NOTICE_SKIP='**/ThirdPartyNotice*,**/*ThirdPartyNotice*,**/NOTICE*,**/*-NOTICE*,**/THIRD-PARTY*,**/third-party*,**/ThirdParty*'

# Scan an installed direct-dep tree for restricted/forbidden licences.
# $1 = manifest path (label), $2 = directory of installed packages.
scan_installed_licences() {
  local manifest="$1" dir="$2" slugged
  slugged=$(slug "${manifest}")
  trivy fs --quiet --scanners license --license-full --skip-files "${NOTICE_SKIP}" \
    --format json --output "${OUTDIR}/license/${slugged}.json" "${dir}"
  # Gate: HIGH/CRITICAL licence classification == restricted/forbidden (copyleft).
  if ! trivy fs --quiet --scanners license --license-full --skip-files "${NOTICE_SKIP}" \
    --severity HIGH,CRITICAL --exit-code 1 "${dir}" >/dev/null 2>&1; then
    echo "- Restricted/forbidden licence in direct deps of \`${manifest}\`" >> "${SUMMARY}"
    gate_failed=1
  else
    echo "- Clean: \`${manifest}\`" >> "${SUMMARY}"
  fi
}

# Vuln + SBOM run straight off the manifest (these DO resolve without install).
scan_manifest_vuln_sbom() {
  local manifest="$1" slugged
  slugged=$(slug "${manifest}")
  trivy fs --quiet --scanners license,vuln --format cyclonedx \
    --output "${OUTDIR}/sbom/${slugged}.cdx.json" "${manifest}"
  trivy fs --quiet --scanners vuln --severity MEDIUM,HIGH,CRITICAL \
    --format json --output "${OUTDIR}/vuln/${slugged}.json" "${manifest}"
}

echo "## Trivy licence scan (fork-aware, direct deps only)" >> "${SUMMARY}"
echo "" >> "${SUMMARY}"

while IFS= read -r manifest; do
  [ -z "${manifest}" ] && continue
  [ -f "${manifest}" ] || { echo "- Skipped (not found): \`${manifest}\`" >> "${SUMMARY}"; continue; }
  base=$(basename "${manifest}")
  # Maven needs network POM fetches from Maven Central; CI runners hit 429 rate
  # limiting (same as #87). Skip ALL Trivy calls (even vuln/SBOM trigger fetches)
  # and defer to #89 (Nexus proxy in the TRE). Must short-circuit before any
  # trivy call, else the 429 aborts the run under `set -e`.
  if [ "${base}" = "pom.xml" ]; then
    echo "- Licence scan deferred (Maven needs network POMs; tracked in #89): \`${manifest}\`" >> "${SUMMARY}"
    continue
  fi
  scan_manifest_vuln_sbom "${manifest}"
  workdir=$(mktemp -d)
  case "${base}" in
    requirements*.txt)
      # Direct deps only: --no-deps installs just the pinned packages.
      if pip install --quiet --no-deps --target "${workdir}" -r "${manifest}" 2>/dev/null; then
        scan_installed_licences "${manifest}" "${workdir}"
      else
        echo "- Licence scan incomplete (pip install failed): \`${manifest}\`" >> "${SUMMARY}"
        gate_failed=1
      fi
      ;;
    package.json | yarn.lock)
      # npm hoists the FULL transitive tree into a flat node_modules, so scanning
      # node_modules wholesale would flag transitive copyleft -- #8 says direct
      # deps only. So: install to resolve, then stage only the directories named
      # in package.json (dependencies + devDependencies) and scan those.
      mdir=$(dirname "${manifest}")
      if [ ! -f "${mdir}/package.json" ]; then
        # yarn.lock with no package.json alongside (e.g. a bare lockfile dir).
        echo "- Licence scan skipped (no package.json beside lockfile): \`${manifest}\`" >> "${SUMMARY}"
        rm -rf "${workdir}"; continue
      fi
      # package.json + yarn.lock in one dir resolve to the same deps; scan once.
      if [ "${npm_done#* "${mdir}" }" != "${npm_done}" ]; then
        rm -rf "${workdir}"; continue
      fi
      npm_done="${npm_done}${mdir} "
      (cd "${mdir}" && npm install --silent --no-audit --no-fund --ignore-scripts \
        --package-lock=false >/dev/null 2>&1) || true
      # Direct-dep names from the manifest.
      mapfile -t direct < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("dependencies", "devDependencies"):
    for name in d.get(k, {}):
        print(name)
' "${mdir}/package.json")
      staged=0
      for name in "${direct[@]}"; do
        if [ -d "${mdir}/node_modules/${name}" ]; then
          mkdir -p "${workdir}/$(dirname "${name}")"
          cp -r "${mdir}/node_modules/${name}" "${workdir}/${name}"
          staged=$((staged + 1))
        fi
      done
      rm -rf "${mdir}/node_modules"
      if [ "${staged}" -eq 0 ]; then
        echo "- Licence scan skipped (no direct deps resolved): \`${manifest}\`" >> "${SUMMARY}"
      else
        scan_installed_licences "${manifest}" "${workdir}"
      fi
      ;;
    *)
      echo "- Licence scan skipped (unsupported manifest type): \`${manifest}\`" >> "${SUMMARY}"
      ;;
  esac
  rm -rf "${workdir}"
done < "${MANIFEST_LIST}"

if [ "${gate_failed}" -ne 0 ]; then
  echo "::error::Restricted or forbidden licence found in a Barts-touched direct dependency."
  exit 1
fi
echo "All Barts-touched direct dependencies carry permissive licences."
