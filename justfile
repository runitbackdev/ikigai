# Ikigai development. `just` lists these; local recipes act on the box you are sitting at
# (dogfooding), the nix ones on the flake.

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
    qml=/run/current-system/sw/share/ikigai/shell/shell.qml
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

# Restart the installed shell and bridge units
restart:
    systemctl --user daemon-reload && systemctl --user restart ikigai-bridge.service ikigai-shell.service

# ---- the flake ----------------------------------------------------------------------

# Build one of the flake's packages, e.g. `just build cosmic-comp`; `just build` lists them
build pkg="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{pkg}}" ]; then nix flake show --json 2>/dev/null | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["packages"]["x86_64-linux"]))'; exit 0; fi
    nix build --print-out-paths "{{tree}}#{{pkg}}"

# Switch the box you are sitting at to this tree, with your personal flake's host: `just switch [flake] [host]`
switch flake=env("IKIGAI_FLAKE", "/etc/nixos") host="":
    #!/usr/bin/env bash
    set -euo pipefail
    host="{{host}}"; [ -n "$host" ] || host=$(hostname)
    sudo nixos-rebuild switch --flake "{{flake}}#$host" --override-input ikigai "path:{{tree}}"

# The example host as a QEMU VM, to the greeter (needs KVM; `ikigai`/`ikigai` logs in)
vm:
    nix run "{{tree}}#vm"

# Build the installer ISO into result/iso/
iso:
    nix build "{{tree}}#iso"

# Rebuild the theme files from palette.json; `ikigai.theme` in the flake picks the theme
theme name="ikigai":
    python3 scripts/theme-build.py themes/{{name}}

# ---- checks ------------------------------------------------------------------------

# What is installed and running on this box
doctor:
    ikigai-doctor

# The cheap checks: bash -n, shellcheck, the flake's own checks (clippy and tests run inside)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{tree}}"
    for f in bin/* scripts/*.sh nix/installer/ikigai-install; do
      case "$(head -1 "$f")" in *python*) python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f" ;; *) bash -n "$f" ;; esac
    done
    echo "syntax ok"
    if command -v shellcheck >/dev/null; then
      shellcheck -S warning $(grep -lE '^#!.*(ba)?sh' bin/*) scripts/*.sh nix/installer/ikigai-install
      echo "shellcheck ok"
    else echo "shellcheck not installed; CI runs it"; fi
    find themes config -type f \( -name '*.ron' -o -path '*/v[0-9]/*' \) | while read -r f; do grep -q . "$f" || { echo "empty config file: $f"; exit 1; }; done
    python3 -c 'import json, glob; [json.load(open(f)) for f in ["config/ikigai/shell.json", *glob.glob("themes/*/shell.json")]]'
    echo "configs ok"
    nix flake check "{{tree}}"

# The layer-shell regression test: stock Qt hide/show and lock/unlock under a nested cosmic-comp (`just comp-test path/to/cosmic-comp`)
comp-test comp="cosmic-comp":
    scripts/comp-test.sh {{comp}}

# A tray item with a submenu on the rail, for trying the tray menus by hand; Ctrl+C or its Quit removes it
tray-fixture:
    #!/usr/bin/env bash
    # PyGObject is what ikigai-caffeinate's interpreter has; borrow it.
    py=$(sed -n '1s/^#!//p' "$(dirname "$(readlink -f "$(command -v ikigai-caffeinate)")")/.ikigai-caffeinate-wrapped")
    exec "$py" scripts/tray-fixture.py

# A client under a build of the fork, nested, with this tree's config and cursors (`just comp-try path/to/cosmic-comp ghostty`)
comp-try comp="cosmic-comp" *args:
    scripts/comp-try.sh {{comp}} {{args}}
