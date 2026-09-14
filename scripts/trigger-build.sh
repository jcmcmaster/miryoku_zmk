#!/usr/bin/env bash
# Trigger the "Build Inputs" GitHub Actions workflow (.github/workflows/build-inputs.yml)
# with separate inputs for the Graphite left and right halves.
set -euo pipefail

board='nice_nano//zmk'
alphas='Graphite'
left_shield='corne_left nice_view_adapter nice_view'
right_shield='corne_right nice_view_adapter nice_view'
left_kconfig=$'CONFIG_ZMK_POINTING=y\nCONFIG_ZMK_STUDIO=y\nCONFIG_ZMK_STUDIO_LOCKING=n'
left_snippet='studio-rpc-usb-uart'

trigger() {
  local label=$1
  local shield=$2
  shift 2

  gh workflow run build-inputs.yml \
    -f "board=$board" \
    -f "shield=$shield" \
    -f "alphas=$alphas" \
    "$@"

  sleep 3
  local run_id
  local run_url
  run_id=$(gh run list --workflow build-inputs.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  run_url=$(gh run view "$run_id" --json url --jq '.url')
  echo "$label run: $run_url"
}

trigger left "$left_shield" \
  -f "kconfig=$left_kconfig" \
  -f "snippet=$left_snippet"
trigger right "$right_shield"
