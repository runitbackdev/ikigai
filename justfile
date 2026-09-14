# Ikigai development. `just` lists these; local recipes act on the box you are sitting at
# (dogfooding), `just vm ...` on the QEMU test VM (scripts/vm.sh).

set positional-arguments

tree := justfile_directory()
state := env("IKIGAI_STATE", env("XDG_STATE_HOME", env("HOME") / ".local/state") / "ikigai")
run := env("XDG_RUNTIME_DIR", "/run/user/1000")

[private]
default:
    @just --list --unsorted

# ---- the shell, live ---------------------------------------------------------------

# Run the shell from this tree in place of the installed one; edits reload live, Ctrl+C restores
shell *args:
    scripts/dev-shell.sh "$@"

# The greeter from this tree in a nested cosmic-comp window (real PAM: the right password ends it)
greeter *args:
    scripts/dev-greeter.sh "$@"

# Call into the running shell, e.g. `just ipc switcher next`; no arguments lists the targets
ipc *args:
    #!/usr/bin/env bash
    set -euo pipefail
    qml=/usr/local/share/ikigai/shell/shell.qml
    [ -r "{{run}}/ikigai/dev-shell" ] && qml=$(cat "{{run}}/ikigai/dev-shell")
    if [ $# -eq 0 ]; then qs ipc -p "$qml" show; else qs ipc -p "$qml" call "$@"; fi

# Follow the bridge socket: every toplevel and workspace event as pretty JSON
bridge:
    #!/usr/bin/env python3
    import json, socket, sys
    s = socket.socket(socket.AF_UNIX); s.connect("{{run}}/ikigai-bridge.sock")
    for line in s.makefile("r"):
        try: print(json.dumps(json.loads(line), indent=1))
        except ValueError: print(line, end="")
        sys.stdout.flush()

# Follow the session's units and log together
logs:
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'kill 0' EXIT
    [ -f "{{run}}/ikigai-session.log" ] && tail -n 20 -F "{{run}}/ikigai-session.log" | sed 's/^/session  | /' &
    journalctl --user -f -n 50 -o cat -u 'ikigai-*' -u vicinae -u cosmic-comp* 2>/dev/null | sed 's/^/journal  | /' &
    wait

# Screenshot the local session through the shell's picker (clipboard + ~/Pictures/Screenshots)
shot kind="screen":
    ikigai-shot {{kind}}

# ---- installing from this tree ----------------------------------------------------

# Run one installer step from this tree, e.g. `just install session`, `just install configs -- IKIGAI_FORCE=1`
install step *env:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "{{tree}}/install/{{step}}.sh" ] || { echo "no such step; have: $(ls {{tree}}/install | sed 's/\.sh$//' | tr '\n' ' ')" >&2; exit 2; }
    mkdir -p "{{state}}"
    env IKIGAI_PATH="{{tree}}" IKIGAI_STATE="{{state}}" "${@:2}" bash "{{tree}}/install/{{step}}.sh"

# Rerun every installer step that changed since the installed commit, then record HEAD as installed
update:
    #!/usr/bin/env bash
    set -euo pipefail
    installed=$(cat "{{state}}/installed_commit" 2>/dev/null || true)
    head=$(git -C "{{tree}}" rev-parse HEAD)
    if [ -z "$installed" ]; then echo "never installed; run install.sh" >&2; exit 1; fi
    if [ "$installed" = "$head" ] && git -C "{{tree}}" diff --quiet HEAD -- install; then echo "installed = HEAD ${head:0:7}; nothing to do"; exit 0; fi
    steps=$( { git -C "{{tree}}" diff --name-only "$installed" HEAD -- install; git -C "{{tree}}" diff --name-only HEAD -- install; } | sed 's|install/||; s|\.sh$||' | sort -u)
    # Steps read files outside install/ too: a shell, bin, session, theme or config change means its step.
    changed=$(git -C "{{tree}}" diff --name-only "$installed" HEAD; git -C "{{tree}}" diff --name-only HEAD)
    grep -qE '^(shell|session)/' <<<"$changed" && steps="$steps session"
    grep -qE '^bin/' <<<"$changed" && steps="$steps services"
    grep -qE '^(config|icons)/' <<<"$changed" && steps="$steps configs"
    grep -qE '^(themes|cursors)/' <<<"$changed" && steps="$steps theme"
    grep -qE '^greeter/' <<<"$changed" && steps="$steps greeter"
    grep -qE '^packages/[^/]+/PKGBUILD' <<<"$changed" && steps="$steps packages"
    grep -qE '^firewall/' <<<"$changed" && steps="$steps firewall"
    # A step deleted since the installed commit shows up in the diff too; only run what exists.
    steps=$(for s in $steps; do [ -f "{{tree}}/install/$s.sh" ] && echo "$s"; done | sort -u | tr '\n' ' ')
    echo "installed ${installed:0:7} -> ${head:0:7}; steps: $steps"
    for s in $steps; do echo "==> $s"; just install "$s"; done
    echo "$head" > "{{state}}/installed_commit"
    echo "done; restart the shell (just restart) or log out for session/greeter changes"

# Restart the installed shell and bridge units
restart:
    systemctl --user daemon-reload && systemctl --user restart ikigai-bridge.service ikigai-shell.service

# Rebuild the theme files from palette.json and apply them (`just theme` = ikigai)
theme name="ikigai":
    python3 scripts/theme-build.py themes/{{name}}
    IKIGAI_PATH="{{tree}}" bin/ikigai-theme-set {{name}}

# ---- checks ------------------------------------------------------------------------

# What is installed, running, patched, and drifted on this box
doctor:
    IKIGAI_PATH="{{tree}}" bin/ikigai-doctor

# Seeded user configs vs. config/: current, behind, or edited by hand (--diff shows edits)
config-diff *args:
    scripts/config-diff.sh "$@"

# The cheap checks: bash -n, shellcheck, cargo clippy + test, json/config sanity
check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{tree}}"
    for f in boot.sh install.sh install/*.sh bin/* scripts/*.sh; do bash -n "$f"; done
    echo "syntax ok"
    if command -v shellcheck >/dev/null; then
      shellcheck -S warning boot.sh install.sh install/*.sh bin/* scripts/*.sh && echo "shellcheck ok"
    else echo "shellcheck not installed (pacman -S shellcheck); CI runs it"; fi
    (cd session && cargo clippy --locked -q --all-targets -- -D warnings && cargo test --locked -q) && echo "session crate ok"
    find themes config -type f \( -name '*.ron' -o -path '*/v[0-9]/*' \) | while read -r f; do grep -q . "$f" || { echo "empty config file: $f"; exit 1; }; done
    python3 -c 'import json, glob; [json.load(open(f)) for f in ["archinstall.json", "config/ikigai/shell.json", "config/zen/policies.json", *glob.glob("themes/*/shell.json")]]'
    echo "configs ok"

# The layer-shell regression test: stock Qt hide/show and lock/unlock under a nested cosmic-comp (`just comp-test target/fastdebug/cosmic-comp`)
comp-test comp="cosmic-comp":
    scripts/comp-test.sh {{comp}}

# The full CI check in an archlinux container (needs docker): package names, everything
ci:
    docker run --rm -v "{{tree}}:/src:ro" -w /src archlinux:latest bash scripts/ci-check.sh

# ---- the VM -------------------------------------------------------------------------

# The QEMU test VM: `just vm` lists its commands (fetch, create, install, serve, seal, reset, run, ssh, sync ...)
vm *args:
    scripts/vm.sh "$@"
