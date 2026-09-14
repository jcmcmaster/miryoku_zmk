#!/usr/bin/env bash
# Trigger the "Build Inputs" GitHub Actions workflow (.github/workflows/build-inputs.yml)
# via `gh workflow run`. See docs/build-inputs.md for the full field reference, board-name
# quirks (e.g. board "nice_nano//zmk"), and known-good kconfig combos.
#
# Requires: gh CLI, authenticated (`gh auth status`), run from inside this repo (or pass
# --repo owner/name).
#
# Usage:
#   scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left,corne_right --alphas Graphite
#   scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left --no-mouse
#   scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left --studio --watch
#
# Any Build Inputs input (see build-inputs.yml) can be set with --<name> <value>:
#   --board --shield --alphas --nav --layers --mapping --custom-config --kconfig
#   --snippet --branches --modules
# NOTE: alphas layout (e.g. Graphite) goes in --alphas, not --nav; --nav only accepts
# default/invertedT/vi. Nothing enforces that server-side, so a stray --nav Graphite is
# silently accepted and silently does nothing.
# --kconfig may be repeated; values are joined with newlines.
# --mouse (default on) ensures "CONFIG_ZMK_POINTING=y" is included in --kconfig.
# --no-mouse disables that default (use when you supply your own pointing config, or none).
# --studio (default off) adds "CONFIG_ZMK_STUDIO=y" + "CONFIG_ZMK_STUDIO_LOCKING=n" to
# --kconfig and defaults --snippet to "studio-rpc-usb-uart" (unless --snippet is given).
# --watch streams the triggered run with `gh run watch` until it completes.
# --repo owner/name overrides the repo gh operates on (default: inferred from cwd).

set -euo pipefail

workflow='build-inputs.yml'
board=''
shield=''
alphas=''
nav=''
layers=''
mapping=''
custom_config=''
kconfig_lines=()
snippet=''
branches=''
modules=''
mouse=1
studio=0
watch=0
repo=''
usage() {
  cat <<'EOF'
Usage:
  scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left,corne_right --alphas Graphite
  scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left --no-mouse
  scripts/trigger-build.sh --board nice_nano//zmk --shield corne_left --studio --watch

Any Build Inputs input (see build-inputs.yml) can be set with --<name> <value>:
  --board --shield --alphas --nav --layers --mapping --custom-config --kconfig
  --snippet --branches --modules
--kconfig may be repeated; values are joined with newlines.
--mouse (default on) ensures "CONFIG_ZMK_POINTING=y" is included in --kconfig.
--no-mouse disables that default (use when you supply your own pointing config, or none).
--watch streams the triggered run with `gh run watch` until it completes.
--repo owner/name overrides the repo gh operates on (default: inferred from cwd).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --board) board="$2"; shift 2 ;;
    --shield) shield="$2"; shift 2 ;;
    --alphas) alphas="$2"; shift 2 ;;
    --nav) nav="$2"; shift 2 ;;
    --layers) layers="$2"; shift 2 ;;
    --mapping) mapping="$2"; shift 2 ;;
    --custom-config) custom_config="$2"; shift 2 ;;
    --kconfig) kconfig_lines+=("$2"); shift 2 ;;
    --snippet) snippet="$2"; shift 2 ;;
    --branches) branches="$2"; shift 2 ;;
    --modules) modules="$2"; shift 2 ;;
    --studio) studio=1; shift ;;
    --mouse) mouse=1; shift ;;
    --no-mouse) mouse=0; shift ;;
    --watch) watch=1; shift ;;
    --repo) repo="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$board" ]; then
  echo "error: --board is required (this is a required input on $workflow)" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found; install it or trigger the workflow from the GitHub UI" >&2
  exit 1
fi

if [ "$mouse" -eq 1 ]; then
  have_pointing=0
  for line in "${kconfig_lines[@]+"${kconfig_lines[@]}"}"; do
    case "$line" in
      *CONFIG_ZMK_POINTING=y*) have_pointing=1 ;;
    esac
  done
  if [ "$have_pointing" -eq 0 ]; then
    kconfig_lines+=('CONFIG_ZMK_POINTING=y')
  fi
fi

if [ "$studio" -eq 1 ]; then
  have_studio=0
  have_locking=0
  for line in "${kconfig_lines[@]+"${kconfig_lines[@]}"}"; do
    case "$line" in
      *CONFIG_ZMK_STUDIO=y*) have_studio=1 ;;
      *CONFIG_ZMK_STUDIO_LOCKING*) have_locking=1 ;;
    esac
  done
  [ "$have_studio" -eq 0 ] && kconfig_lines+=('CONFIG_ZMK_STUDIO=y')
  [ "$have_locking" -eq 0 ] && kconfig_lines+=('CONFIG_ZMK_STUDIO_LOCKING=n')
  [ -z "$snippet" ] && snippet='studio-rpc-usb-uart'
fi

kconfig=''
if [ "${#kconfig_lines[@]}" -gt 0 ]; then
  kconfig=$(printf '%s\n' "${kconfig_lines[@]}")
  kconfig=${kconfig%$'\n'}
fi

args=(-f "board=$board")
[ -n "$shield" ] && args+=(-f "shield=$shield")
[ -n "$alphas" ] && args+=(-f "alphas=$alphas")
[ -n "$nav" ] && args+=(-f "nav=$nav")
[ -n "$layers" ] && args+=(-f "layers=$layers")
[ -n "$mapping" ] && args+=(-f "mapping=$mapping")
[ -n "$custom_config" ] && args+=(-f "custom_config=$custom_config")
[ -n "$kconfig" ] && args+=(-f "kconfig=$kconfig")
[ -n "$snippet" ] && args+=(-f "snippet=$snippet")
[ -n "$branches" ] && args+=(-f "branches=$branches")
[ -n "$modules" ] && args+=(-f "modules=$modules")

gh_repo_args=()
[ -n "$repo" ] && gh_repo_args+=(-R "$repo")

echo "triggering $workflow with:" >&2
printf '  %s\n' "${args[@]}" >&2

gh workflow run "$workflow" "${gh_repo_args[@]}" "${args[@]}"

# workflow_dispatch does not return a run id; poll the most recent run for this workflow.
sleep 3
run_id=$(gh run list "${gh_repo_args[@]}" --workflow "$workflow" --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$run_id" ]; then
  echo "triggered, but could not resolve the run id; check: gh run list --workflow $workflow" >&2
  exit 0
fi

run_url=$(gh run view "${gh_repo_args[@]}" "$run_id" --json url --jq '.url')
echo "run: $run_url"

if [ "$watch" -eq 1 ]; then
  gh run watch "${gh_repo_args[@]}" "$run_id" --exit-status
fi
