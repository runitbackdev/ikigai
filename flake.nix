{
  description = "Ikigai: a developer desktop on NixOS. A reason to boot.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Zen is a binary release with no nixpkgs package; this flake wraps it like Firefox.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  # The binary cache CI fills (.github/workflows/ci.yml): the compositor fork, the session
  # crate and the shell plugins, so an install downloads them instead of compiling.
  nixConfig = {
    extra-substituters = [ "https://ikigai-desktop.cachix.org" ];
    extra-trusted-public-keys = [ "ikigai-desktop.cachix.org-1:REPLACE_WITH_THE_KEY_FROM_APP_CACHIX_ORG" ];
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      zen-browser,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfree = true;
      };
      lib = nixpkgs.lib;
    in
    {
      # Every package Ikigai builds itself, plus the compositor fork in place of nixpkgs'.
      overlays.default = import ./nix/pkgs { inherit inputs; };

      # The desktop. A host imports this and sets `ikigai.*` (nix/ikigai/default.nix).
      nixosModules.ikigai = {
        imports = [
          ./nix/ikigai
          home-manager.nixosModules.home-manager
        ];
        nixpkgs.overlays = [ self.overlays.default ];
        nixpkgs.config.allowUnfree = true;
        home-manager.sharedModules = [ self.homeModules.ikigai ];
      };
      nixosModules.default = self.nixosModules.ikigai;

      # The user half: every app config, the theme files, the user units' environment.
      homeModules.ikigai = ./nix/home;
      homeModules.default = self.homeModules.ikigai;

      # `nix flake init -t github:runitbackdev/ikigai#personal` starts a private flake with
      # a host and a user, which is what the installer writes to /etc/nixos.
      templates.personal = {
        path = ./templates/personal;
        description = "A personal flake for one Ikigai box: host, hardware, user";
      };

      packages.${system} = {
        inherit (pkgs)
          cosmic-comp
          ikigai-session
          ikigai-shell
          ikigai-shell-plugins
          ikigai-theme
          ikigai-icons
          ikigai-cosmic-config
          phosphor-font
          zen
          ;
        ikigai-install = pkgs.callPackage ./nix/installer/package.nix { };
        ikigai-commands = pkgs.symlinkJoin {
          name = "ikigai-commands";
          paths = lib.filter lib.isDerivation (lib.attrValues pkgs.ikigai-commands);
        };
        # The installer ISO (nix/iso.nix): boots to the Ikigai installer on tty1.
        iso = self.nixosConfigurations.iso.config.system.build.isoImage;
        # The example host as a QEMU VM: `nix run .#vm` boots it to the greeter.
        vm = self.nixosConfigurations.example.config.system.build.vm;
      };

      nixosConfigurations = {
        # Used by CI and the VM; the shape a personal flake copies.
        example = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.ikigai
            ./hosts/example
          ];
        };
        iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit self; };
          modules = [
            ./nix/iso.nix
            { nixpkgs.overlays = [ self.overlays.default ]; }
          ];
        };
      };

      apps.${system}.vm = {
        type = "app";
        program = "${self.packages.${system}.vm}/bin/run-ikigai-example-vm";
      };

      checks.${system} = {
        example = self.nixosConfigurations.example.config.system.build.toplevel;
        inherit (self.packages.${system})
          cosmic-comp
          ikigai-session
          ikigai-shell
          ikigai-shell-plugins
          ikigai-theme
          ikigai-icons
          ikigai-cosmic-config
          ikigai-commands
          ikigai-install
          phosphor-font
          ;
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
