# constructor dependencies
{
  lib,
  self,
  inputs,
  collectors,
  home-manager,
  flake-utils-plus,
  ...
}: config: channels: let
  pkgs = channels.${config.nixos.hostDefaults.channelName};
  system = pkgs.system;

  mkPortableHomeManagerConfiguration = {
    username,
    configuration,
    pkgs,
    system ? pkgs.system,
  }: let
    homeDirectoryPrefix =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "/Users"
      else "/home";
    homeDirectory = "${homeDirectoryPrefix}/${username}";
  in
    home-manager.lib.homeManagerConfiguration {
      inherit username homeDirectory pkgs system;

      extraModules = config.home.modules ++ config.home.exportedModules;
      extraSpecialArgs = config.home.importables // {inherit self inputs;};

      configuration =
        {
          imports = [configuration];
        }
        // (
          if (pkgs.stdenv.hostPlatform.isLinux && !pkgs.stdenv.buildPlatform.isDarwin)
          then {targets.genericLinux.enable = true;}
          else {}
        );
    };

  homeConfigurationsPortable =
    builtins.mapAttrs
    (n: v:
      mkPortableHomeManagerConfiguration {
        inherit pkgs system;
        username = n;
        configuration = v;
      })
    config.home.users;
in {
  inherit homeConfigurationsPortable;

  # packages = flake-utils-plus.lib.exportPackages self.overlays channels;

  checks =
    (
      # for self.homeConfigurations if present & non empty
      if
        (
          (builtins.hasAttr "homeConfigurations" self)
          && (self.homeConfigurations != {})
        )
      then let
        seive = _: v: v.system == system; # only test for the appropriate system
        collectActivationPackages = n: v: {
          name = "user-" + n;
          value = v.activationPackage;
        };
      in
        lib.filterAttrs seive (lib.mapAttrs' collectActivationPackages self.homeConfigurations)
      else {}
    )
    // (
      # for portableHomeConfigurations if present & non empty
      if (homeConfigurationsPortable != {})
      then let
        collectActivationPackages = n: v: {
          name = "user-" + n;
          value = v.activationPackage;
        };
      in
        # N.B. portable home configurations for Linux/NixOS hosts cannot be built on Darwin!
        lib.mapAttrs' collectActivationPackages homeConfigurationsPortable
      else {}
    );
}
