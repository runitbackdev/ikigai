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
    rev = "913c6e05d8113dc6d83243932cc285eb11a9ad15";
    hash = "sha256-PUl6NmdnLWZ27CI2qk5uLU+Uu5QImzmPJeO2RrlnBKE=";
  };
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-SMyY4YCa7Zx+sfDGq4c35kngCMnU38f4Lq/4XcM3nZI=";
  };
  # Upstream's update script keys on epoch tags; the fork has none.
  passthru = (old.passthru or { }) // { updateScript = null; };
})
