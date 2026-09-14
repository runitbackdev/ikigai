# Third-party files

Vendored verbatim; see the pinned revisions in the `scripts/vendor-*.sh` scripts. The last
two rows are not vendored: they are fetched at build, pinned in `flake.lock` and
`nix/pkgs/phosphor-font.nix`.

| Path | Source | License |
|---|---|---|
| `config/zsh/git-aliases.zsh` | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) `plugins/git/git.plugin.zsh` | MIT |
| `config/zellij/config.kdl` (keybinds) | [zellij-org/zellij](https://github.com/zellij-org/zellij) "Unlock First" preset | MIT |
| `themes/ikigai/wallpaper.jpg` | [NASA SVS 13831](https://svs.gsfc.nasa.gov/13831) — *Doubly Warped World of Binary Black Holes*, Jeremy Schnittman & Brian P. Powell, NASA Goddard | Public domain (NASA) |
| `shell/plugin/blobs/**` | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) `plugin/src/Caelestia/Blobs/` | GPL-3.0 (see `shell/plugin/blobs/LICENSE`; `shell/` is GPL-3.0 as a whole) |
| `shell/Icons.qml` | [phosphor-icons/web](https://github.com/phosphor-icons/web) `src/regular/style.css` (generated glyph table) | MIT |
| `icons/Ikigai/**` | [phosphor-icons/core](https://github.com/phosphor-icons/core) `assets/regular/` (SVGs renamed per `icons/phosphor.map`) | MIT |
| `cursors/bibata/**` | [ful1e5/Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor) SVG sources | GPL-3.0 |
| `zen-browser` flake input (`flake.nix`, wrapped by `nix/pkgs/zen.nix`) | [0xc000022070/zen-browser-flake](https://github.com/0xc000022070/zen-browser-flake), which packages [zen-browser/desktop](https://github.com/zen-browser/desktop) binary releases | Zen is MPL-2.0; the flake ships no license file |
| `nix/pkgs/phosphor-font.nix` (fetched, `share/fonts/truetype`) | [phosphor-icons/web](https://github.com/phosphor-icons/web) `src/*/Phosphor*.ttf`, v2.1.2 | MIT |
