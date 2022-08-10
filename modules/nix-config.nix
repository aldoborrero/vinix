{lib, ...}: let
  experimental-features = [
    "flakes"
    "nix-command"
  ];
  substituters = [
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
in {
  # package and option is from fup
  nix.generateRegistryFromInputs = lib.mkDefault true;

  # missing merge semantics in this option force us to use extra-* for now
  nix.extraOptions = ''
    extra-experimental-features = ${lib.concatStringsSep " " experimental-features}
    extra-substituters = ${lib.concatStringsSep " " substituters}
    extra-trusted-public-keys = ${lib.concatStringsSep " " trusted-public-keys}
  '';
}
