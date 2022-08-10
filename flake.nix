{
  description = "vinix configuriguration library";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters = "https://nix-community.cachix.org";
  nixConfig.extra-trusted-public-keys = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixlib.url = "github:nix-community/nixpkgs.lib";

    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs.nixpkgs.follows = "nixlib";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixlib,
    nixpkgs,
    devshell,
    flake-utils-plus,
    darwin,
    home-manager,
    ...
  } @ inputs: let
    internal-modules = import ./src/modules.nix {
      inherit (nixlib) lib;
    };

    importers = import ./src/importers.nix {
      inherit (nixlib) lib;
    };

    collectors = import ./src/collectors.nix {
      inherit (nixlib) lib;
    };

    generators = import ./src/generators.nix {
      inherit (nixlib) lib;
    };

    mkFlake = let
      mkFlake' = import ./src/mkFlake {
        inherit (nixlib) lib;
        inherit (flake-utils-plus.inputs) flake-utils;
        inherit
          collectors
          darwin
          home-manager
          flake-utils-plus
          internal-modules
          ;
      };
    in {
      __functor = _: args: (mkFlake' args).flake;
      options = args: (mkFlake' args).options;
    };

    # Unofficial Flakes Roadmap - Polyfills
    # This project is committed to the Unofficial Flakes Roadmap!
    # .. see: https://demo.hedgedoc.org/s/_W6Ve03GK#

    # Super Stupid Flakes (ssf) / System As an Input - Style:
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin"];

    # Pass this flake(self) as "digga"
    polyfillInputs = self.inputs // {digga = self;};
    polyfillOutput = loc:
      nixlib.lib.genAttrs supportedSystems (
        system:
          import loc {
            inherit system;
            inputs = polyfillInputs;
          }
      );
    # .. we hope you like this style.
    # .. it's adopted by a growing number of projects.
    # Please consider adopting it if you want to help to improve flakes.
  in {
    # what you came for ...
    lib = {
      inherit (flake-utils-plus.inputs.flake-utils.lib) defaultSystems eachSystem eachDefaultSystem filterPackages;
      inherit (flake-utils-plus.lib) exportModules exportOverlays exportPackages mergeAny;
      inherit mkFlake;
      inherit (importers) flattenTree rakeLeaves importOverlays importExportableModules importHosts;
      inherit (generators) mkHomeConfigurations;
      inherit (collectors) collectHosts collectHostsOnSystem;
    };

    # a little extra service ...
    overlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos-modules.nix;
    darwinModules = import ./modules/darwin-modules.nix;

    # templates definitions
    templates = {
      default = self.templates.vinix;
      vinix.path = ./templates/vinix;
      vinix.description = ''
        #   an awesome template for NixOS users, with consideration for common tools like home-manager and more.
        # '';
    };

    # vinix local use
    # system-space and pass sytem and input to each file
    jobs = polyfillOutput ./jobs;
    checks = polyfillOutput ./checks;
    devShell = polyfillOutput ./shell.nix;
  };
}
