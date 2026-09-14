{
  description = "My Ikigai box";

  inputs = {
    ikigai.url = "github:runitbackdev/ikigai";
    nixpkgs.follows = "ikigai/nixpkgs";
  };

  outputs =
    { self, ikigai, nixpkgs }:
    {
      nixosConfigurations.ikigai = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ikigai.nixosModules.ikigai
          ./hosts/ikigai
          ./users/lycanthropy.nix
        ];
      };
    };
}
