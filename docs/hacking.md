# Hacking

## Layout

| | |
|---|---|
| `flake.nix`, `flake.lock` | the flake: the module, the home module, the overlay, the packages, the ISO, the VM, the checks |
| `nix/ikigai/` | the NixOS module, one file per concern |
| `nix/home/` | the Home Manager module: every app config |
| `nix/pkgs/` | the overlay and the packages: the compositor fork, the shell, the session crate, the theme, the commands |
| `nix/iso.nix`, `nix/kexec.nix`, `nix/installer/` | the installer ISO, the same as a kexec image, `ikigai-install` and the live system they share |
| `hosts/example` | the host CI builds and `just vm` boots |
| `templates/personal` | the example personal flake, for `nix flake init` on a NixOS box; the installer writes its own from the answers |
| `bin/` | the `ikigai-*` commands, packaged by `nix/pkgs/commands.nix`; `ikigai-migrate` runs on the Arch side and is not |
| `config/` | the app configs the home module installs, COSMIC's system config, `mimeapps.list` |
| `shell/` | the Quickshell shell, greeter and lock included. `plugin/blobs` is vendored |
| `session/` | Rust: `ikigai-session`, `ikigai-bridge`, `ikigai-outputs`. Their units are in `nix/ikigai/session.nix` |
| `themes/` | `<name>/palette.json` and what `theme-build.py` renders from it |
| `cursors/bibata` | Bibata's SVG sources, vendored |
| `icons/` | the Ikigai icon theme and its Phosphor name map |
| `tools/cosmic-theme-gen` | dev-only: builds the COSMIC theme from `builder.ron` |
| `scripts/` | theme pipeline, vendoring, the dev shell and greeter, `comp-test` |
| `boot.ps1` | the Windows entry point |

## Recipes

`just` lists them. Local ones act on the box you are sitting at.

| | |
|---|---|
| `just shell` | the shell from this tree in place of the installed one, live reload; Ctrl+C restores. cosmic-comp's shortcuts follow it. The plugins come from the installed system: a plugin change is `just build ikigai-shell-plugins` and a rebuild |
| `just greeter` | the greeter in a nested cosmic-comp window, real PAM |
| `just ipc [target call]` | call into the running shell; no arguments lists targets |
| `just bridge`, `just logs` | follow the bridge socket, the session's units |
| `just shot [kind]` | a screenshot through the picker |
| `just restart` | the shell and bridge units |
| `just build [pkg]` | one of the flake's packages; no argument lists them |
| `just switch [flake] [host]` | rebuild this box from this tree: your personal flake with `--override-input ikigai` pointing here |
| `just vm` | the example host in QEMU |
| `just iso` | the installer ISO into `result/iso/` |
| `just theme [name]` | rebuild the theme files from `palette.json` |
| `just doctor` | what is running |
| `just check` | bash -n, shellcheck, config sanity, `nix flake check` (the crate's tests run inside its build) |
| `just comp-test [binary]` | the layer-shell regression test for the compositor fork, nested |

## The VM

`nix run .#vm` boots `hosts/example` to the greeter in QEMU with KVM; `ikigai` / `ikigai`
logs in. A virtio GPU with GL so cosmic-comp renders through virgl, 4 GiB and four cores.
Not verified yet: the VM output is new with the move to NixOS and has not been booted.
`scripts/vm.sh` and the Hyper-V harness are gone with the Arch path.

## Vendoring

Each `scripts/vendor-*.sh` pins a revision and rewrites its target: the blob plugin, the
cursors, the icon theme, the glyph table, oh-my-zsh's git aliases. Two things are fetched
at build instead: Phosphor's font (`nix/pkgs/phosphor-font.nix`, at the same release as
the glyph table) and Zen (the `zen-browser` flake input, wrapped by `nix/pkgs/zen.nix`).
Add a row to `THIRD_PARTY.md` when adding either kind.

## CI

`ci.yml` on every push: shellcheck at warning, then four jobs in a chain, each with its
own log and each pushing to the `ikigai-desktop` Cachix cache before the next starts:
`nix flake check --no-build`, the compositor fork, every Ikigai package, the example
system. Pushing needs the `CACHIX_AUTH_TOKEN` secret; without it the build runs
and nothing is pushed. `iso.yml` builds the ISO and the kexec image (`ikigai-kexec.tar.gz`, what
`ikigai-migrate` fetches) and uploads both to the rolling `iso` GitHub release when the
installer's inputs change on main, or by hand from the Actions tab.

The cache is `https://ikigai-desktop.cachix.org`. Its public key is set in `flake.nix`
(`nixConfig`), `nix/ikigai/nix.nix` and `nix/installer/live.nix`. Until CI has pushed
once, every install compiles the compositor, the session crate and the shell plugins itself.

## The forks

cosmic-comp and Smithay live at github.com/runitbackdev, branch `ikigai`, cut from epoch
1.8.0 plus one commit per fix ([upstream.md](upstream.md)). `nix/pkgs/cosmic-comp.nix` is
nixpkgs' package with the fork's source. To ship a change: commit on the fork, push, put
the new `rev`, `hash` and `cargoHash` in that file (`nix build .#cosmic-comp` reports each
mismatch in turn), and merge to main; CI builds it into the cache, `ikigai-update`
installs it. A Smithay change goes through cosmic-comp's `Cargo.toml` the same way. Test
it first with `just comp-test $(nix build --print-out-paths .#cosmic-comp)/bin/cosmic-comp`.

nixpkgs ships the other COSMIC components at epoch 1.6.0 while the fork is at 1.8.0. A
known gap to watch.

## Adding a package

A file in `nix/pkgs/`, a line in `nix/pkgs/default.nix`, and its name in `flake.nix`
under `packages` and `checks` and in the build list in `ci.yml`, so CI builds it and the
cache has it.

## Adding a command

A script in `bin/` and an entry in `nix/pkgs/commands.nix` naming its runtime tools and
the `@names@` to substitute. shellcheck runs at build. The module installs every command;
the greeter unit names one.
