# cosmic-comp from Ikigai's fork: nixpkgs' package with the source swapped for
# runitbackdev/cosmic-comp, branch ikigai. What the fork carries: docs/upstream.md.
# fetchgit rather than fetchFromGitHub so the hash is the tree's and the fetch is a
# clone, which works from behind proxies that block the archive endpoint. Bump rev,
# hash and cargoHash together: `nix build .#cosmic-comp` reports each mismatch.
{ cosmic-comp, fetchgit, rustPlatform }:
cosmic-comp.overrideAttrs (finalAttrs: old: {
  version = "1.8.0-ikigai";
  src = fetchgit {
    url = "https://github.com/runitbackdev/cosmic-comp";
    rev = "b56fc012ecbaa5c5c1976c45671a87a813abf858";
    hash = "sha256-VeyRzzeUdIzA0VZNjdkDTg+x0+g5IQx/uxswjc8t+eM=";
  };
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-SMyY4YCa7Zx+sfDGq4c35kngCMnU38f4Lq/4XcM3nZI=";
  };
  # Thin LTO, as Arch's package built it: fat LTO on the test binary takes more memory than
  # a CI runner has, and the runner dies mid-link.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace Cargo.toml --replace-fail 'lto = "fat"' 'lto = "thin"'
  '';
  # Upstream's update script keys on epoch tags; the fork has none.
  passthru = (old.passthru or { }) // { updateScript = null; };
})
