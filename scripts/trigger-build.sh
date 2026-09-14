#!/usr/bin/env bash
# Trigger the "Build Inputs" GitHub Actions workflow (.github/workflows/build-inputs.yml)
# with this fork's actual build options. See docs/build-inputs.md for why each kconfig
# line is needed. No flags — if board/alphas/kconfig change, edit the values below.
set -euo pipefail

board='nice_nano//zmk'
alphas='Graphite'
kconfig=$'CONFIG_ZMK_POINTING=y\nCONFIG_ZMK_STUDIO=y\nCONFIG_ZMK_STUDIO_LOCKING=n'

gh workflow run build-inputs.yml \
  -f "board=$board" \
  -f "alphas=$alphas" \
  -f "kconfig=$kconfig"

sleep 3
run_id=$(gh run list --workflow build-inputs.yml --limit 1 --json databaseId --jq '.[0].databaseId')
run_url=$(gh run view "$run_id" --json url --jq '.url')
echo "run: $run_url"
