# AGENTS.md

## What this repo is

Fork of [manna-harbour/miryoku_zmk](https://github.com/manna-harbour/miryoku_zmk) — the
[Miryoku](https://github.com/manna-harbour/miryoku) layout implemented for
[ZMK](https://zmkfirmware.dev/). Miryoku itself is generated from a portable definition and
implemented per-firmware; this repo is the ZMK implementation only.

This fork's purpose beyond upstream: add a **Graphite** alphas layout
(`MIRYOKU_ALPHAS_GRAPHITE`) and **ZMK Studio snippet** build support (`snippet` workflow
input, e.g. `studio-rpc-usb-uart`). Neither is part of upstream Miryoku — keep them clearly
additive so upstream can still be merged in without conflict, and don't rename/remove
upstream options while adding fork-specific ones.

## Layout / architecture

- `config/<keyboard>.keymap` — one tiny file per supported keyboard/split-half. Always the
  same shape: include `custom_config.h`, a `mapping/<layout>/<board>.h`, then
  `miryoku.dtsi`. Never hand-write keymap layers here — everything is generated from the
  macros below.
- `miryoku/miryoku.h`, `miryoku/miryoku.dtsi` — core Miryoku layer/behavior definitions
  (upstream, layout-agnostic).
- `miryoku/miryoku_babel/` — the "babel" layer that resolves alternative alphas/extra/tap
  layouts and layer choices from `#define`s into the base/extra/tap key rows:
  - `miryoku_layer_alternatives.h` — one `MIRYOKU_ALTERNATIVES_{BASE,TAP}_<NAME>[_FLIP]`
    macro per alternative layout, each a flat list of `&kp`/`U_MT`/`U_LT` bindings in
    physical key order. `_FLIP` variants swap thumb-cluster layer-tap order for the
    alternate handedness convention.
  - `miryoku_layer_selection.h` — `#elif defined(MIRYOKU_ALPHAS_<NAME>)` /
    `MIRYOKU_EXTRA_<NAME>` / `MIRYOKU_TAP_<NAME>` chains that pick the macro above based on
    which config option was defined. Each of BASE/EXTRA/TAP has a flip and non-flip chain
    (4 chains total to update per new layout).
  - `miryoku_layer_list.h` — layer ordering/list.
- `miryoku/miryoku_kludge_*.dtsi`, `miryoku_mousekeys.*`, `miryoku_shift_functions.*`,
  `miryoku_double_tap_guard.*` — additional/experimental features, each self-contained and
  gated behind its own `#define`, documented in `readme.org` under "Additional and
  Experimental Features".
- `miryoku/custom_config.h` — local override point (upstream keeps this empty; workflow
  `config` input content lands here).
- `.github/workflows/` — `main.yml` is the reusable build workflow (matrix over board,
  shield, alphas/extra/tap/nav/etc, and `snippet`). `build-inputs.yml` and
  `build-example-*.yml` are the user-facing entry points; `test-all-configs.yml`,
  `test-all-boards.yml`, etc. exercise matrices of the above and are gated
  `if: github.repository_owner == 'manna-harbour'` — they will **not** run on this fork, so
  don't rely on them for CI signal here.
- `readme.org` — the actual user-facing docs (Emacs org-mode, not Markdown). Any new option
  or feature must be documented in the matching section here.
- `docs/quickstart/` — separate guide for the no-build-environment workflow path.

## Conventions when adding a new alphas/extra/tap alternative

Follow the existing `GRAPHITE` addition (`git show 509dd86`) as the template:

1. Add `MIRYOKU_ALTERNATIVES_BASE_<NAME>` and `_FLIP`, `MIRYOKU_ALTERNATIVES_TAP_<NAME>` and
   `_FLIP` to `miryoku_layer_alternatives.h`. Row layout is fixed: 3 rows of 10 keys
   (fingers) + 1 row of 10 (thumbs, outer 2 per side are `U_NP`). Match column alignment
   with surrounding macros — this file is hand-aligned, not run through a formatter.
2. Wire `MIRYOKU_ALPHAS_<NAME>` / `MIRYOKU_EXTRA_<NAME>` / `MIRYOKU_TAP_<NAME>` into all
   four chains in `miryoku_layer_selection.h`.
3. Add the option to `.github/workflows/build-inputs.yml` (dropdown list),
   `.github/workflows/main.yml` (only if it needs new passthrough — usually not, alphas
   already flow through), and `.github/workflows/test-all-configs.yml` matrices.
4. Document it in `readme.org` (Options section) — this fork already notes Graphite there
   as fork-specific ("not part of upstream Miryoku"); follow that phrasing for any other
   fork-only addition so it's clear on upstream sync/diff.

## Build / verification

No local ZMK toolchain is assumed to be present. Verification options, in order of
preference:
- If `west`/Zephyr SDK is available locally, build a representative keymap (e.g.
  `config/xmk.keymap` or any `config/*.keymap` including the changed layout) via the normal
  ZMK `west build` flow with `ZMK_CONFIG` pointed at `config/`.
- Otherwise, trigger the `main.yml`-based workflows (`Build Inputs` or a `build-example-*`
  workflow) via GitHub Actions on this fork — `test-all-configs.yml` and friends are
  upstream-only and won't fire here.
- At minimum, sanity-check new/edited macros in `miryoku_layer_alternatives.h` for row/column
  count (40 tokens: 3×10 + 10) and comma placement against a known-good macro of the same
  shape.

## Style

- `.h`/`.dtsi` — C preprocessor macros and devicetree, matching existing whitespace-aligned
  layout tables exactly; don't reformat surrounding macros while touching one.
- `readme.org` — Emacs org-mode markup (`*`/`**` headings, `[[link][text]]`, `~code~`), not
  Markdown.

## Git workflow

- Never push directly to `master` unless explicitly asked to. Default to a feature branch
  and a PR, even for small/follow-up fixes.
