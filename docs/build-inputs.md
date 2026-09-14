# Triggering builds: quick reference

Fork-specific operational note (not an upstream Miryoku doc page). Covers the
`build-inputs.yml` ("Build Inputs") GitHub Actions workflow: how to fill in its fields
correctly, and known-good `kconfig` combos for features that need a Kconfig flag on top
of the Miryoku `#define`s. See `readme.org` for the canonical per-feature description.

## Mouse keys

The `U_MOUSE` layer and its `&mmv`/`&msc`/`&mkp` bindings are always compiled into every
keymap in this repo. They do nothing on the device unless the firmware is built with:

```
CONFIG_ZMK_POINTING=y
```

This is a Zephyr Kconfig flag, not a Miryoku `#define` — it must be supplied per build via
the `kconfig` input (see below), or in `config/<board_or_shield>.conf` for local builds.

## ZMK Studio snippet

This fork adds ZMK Studio snippet build support (`snippet` input, e.g.
`studio-rpc-usb-uart`). To get a working, unlocked Studio connection you also need:

```
CONFIG_ZMK_STUDIO=y
CONFIG_ZMK_STUDIO_LOCKING=n
```

## Build Inputs workflow field reference

`workflow_dispatch` inputs on `.github/workflows/build-inputs.yml`, forwarded as-is into
`main.yml`'s build matrix (each is comma-split into a matrix array, so
`shield: corne_left,corne_right` builds both halves in one run):

| input           | meaning                                               | example                                |
|-----------------|--------------------------------------------------------|------------------------------------------|
| `board`         | MCU board (required)                                  | `nice_nano//zmk`                         |
| `shield`        | keyboard PCB shield, for split/shield-based boards     | `corne_left,corne_right`                 |
| `alphas`        | alternative alphas layout                              | `Graphite`                               |
| `nav`           | nav layer variant                                      | `default` / `invertedT` / `vi`           |
| `layers`        | `default` or `flip`                                    | `default`                                |
| `mapping`       | key mapping override                                   | `default`                                |
| `custom_config` | raw text appended to `custom_config.h`                 | `#define MIRYOKU_KLUDGE_...`             |
| `kconfig`       | raw text appended to `config/<board_or_shield>.conf`   | `CONFIG_ZMK_POINTING=y`                  |
| `snippet`       | ZMK Studio snippet (fork-specific)                     | `studio-rpc-usb-uart`                    |
| `branches`      | ZMK fork/branch(es) to build against                   | `zmkfirmware/zmk/main`                   |
| `modules`       | extra west modules to pull in                          | `owner/repo/branch`                      |

Notes on real values seen in this fork:

- `board` can legitimately contain a double slash, e.g. `nice_nano//zmk` — this repo's
  `main.yml` had to add slash-sanitizing for artifact names specifically because of that
  board string (commit "Sanitize forward slashes in artifact name (fixes nice_nano//zmk
  board)"). Don't "fix" a board value like that; it's expected.
- **`alphas` is where a layout name like `Graphite` goes — not `nav`.** `nav` is a
  `type: choice` input restricted to `default`/`invertedT`/`vi` in the workflow definition,
  but GitHub's `workflow_dispatch` API does not actually enforce `type: choice` values
  server-side, so passing e.g. `nav=Graphite` is silently accepted and silently does
  nothing (`miryoku_layer_selection.h` only matches alphas names against
  `MIRYOKU_ALPHAS_<NAME>`, never `MIRYOKU_NAV_<NAME>`). If a build didn't come out with
  the expected alphas layout, check which field it was actually put in.

Multiple `kconfig` lines: put a real newline in the value (the GitHub UI form and
`gh workflow run -f kconfig=$'A\nB'` both accept this).

## Triggering a run

`scripts/trigger-build.sh` calls `gh workflow run build-inputs.yml` twice — once per
split half — with this fork's build options: `board=nice_nano//zmk`, `alphas=Graphite`,
and each half's `shield`. Only the left half also gets the
`CONFIG_ZMK_POINTING=y` / `CONFIG_ZMK_STUDIO=y` / `CONFIG_ZMK_STUDIO_LOCKING=n` kconfig
combo and the `studio-rpc-usb-uart` snippet (Studio's USB-UART transport only needs to
run on one half). Each run's URL is printed as it's triggered. The script takes no
flags; edit the values at the top of the script if board/shields/alphas/kconfig ever
change.

```
scripts/trigger-build.sh
```

Equivalent manual calls:

```
gh workflow run build-inputs.yml \
  -f board=nice_nano//zmk \
  -f shield='corne_left nice_view_adapter nice_view' \
  -f alphas=Graphite \
  -f kconfig=$'CONFIG_ZMK_POINTING=y\nCONFIG_ZMK_STUDIO=y\nCONFIG_ZMK_STUDIO_LOCKING=n' \
  -f snippet=studio-rpc-usb-uart

gh workflow run build-inputs.yml \
  -f board=nice_nano//zmk \
  -f shield='corne_right nice_view_adapter nice_view' \
  -f alphas=Graphite
```
