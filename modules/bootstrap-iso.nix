let
  getFqdn = config: let
    net = config.networking;
    fqdn =
      if (net ? domain) && (net.domain != null)
      then "${net.hostName}.${net.domain}"
      else net.hostName;
  in
    fqdn;

  protoModule = fullHostConfig: {
    config,
    inputs,
    lib,
    modulesPath,
    self,
    suites,
    ...
  } @ args: {
    imports = ["${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"];

    isoImage = {
      isoBaseName = "bootstrap-" + (getFqdn config);
      contents = [
        {
          source = self;
          target = "/devos/";
        }
      ];
      storeContents =
        [
          self.devShell.${config.nixpkgs.system}
          # include also closures that are "switched off" by the
          # above profile filter on the local config attribute
          fullHostConfig.system.build.toplevel
        ]
        ++ builtins.attrValues inputs;
    };

    # still pull in tools of deactivated profiles
    environment.systemPackages = fullHostConfig.environment.systemPackages;

    networking = {
      # confilcts with networking.wireless which might be slightly
      # more useful on a stick
      networkmanager.enable = lib.mkForce false;

      # confilcts with networking.wireless
      wireless.iwd.enable = lib.mkForce false;

      # Set up a link-local boostrap network
      # See also: https://github.com/NixOS/nixpkgs/issues/75515#issuecomment-571661659
      usePredictableInterfaceNames = lib.mkForce true; # so prefix matching works
      useNetworkd = lib.mkForce true;
      useDHCP = lib.mkForce false;
      dhcpcd.enable = lib.mkForce false;
    };

    systemd.network = {
      # https://www.freedesktop.org/software/systemd/man/systemd.network.html
      networks."boostrap-link-local" = {
        matchConfig = {
          Name = "en* wl* ww*";
        };
        networkConfig = {
          Description = "Link-local host bootstrap network";
          MulticastDNS = true;
          LinkLocalAddressing = "ipv6";
          DHCP = "yes";
        };
        address = [
          # fall back well-known link-local for situations where MulticastDNS is not available
          "fe80::47" # 47: n=14 i=9 x=24; n+i+x
        ];
        extraConfig = ''
          # Unique, yet stable. Based off the MAC address.
          IPv6LinkLocalAddressGenerationMode = "eui64"
        '';
      };
    };
  };
in
  {config, ...}: {
    system.build = {
      bootstrapIso =
        (config.lib.digga.mkBuild (protoModule config))
        .config
        .system
        .build
        .isoImage;
    };
  }
