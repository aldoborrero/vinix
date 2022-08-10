{lib}: let
  getFqdn = c: let
    net = c.config.networking;
    fqdn =
      if (net ? domain) && (net.domain != null)
      then "${net.hostName}.${net.domain}"
      else net.hostName;
  in
    fqdn;
in {
  mkHomeConfigurations = systemConfigurations:
  /*
   *
   Synopsis: mkHomeConfigurations _systemConfigurations_
   
   Generate the `homeConfigurations` attribute expected by `home-manager` cli
   from _nixosConfigurations_ or _darwinConfigurations_ in the form
   _user@hostname_.
   *
   */
  let
    op = attrs: c:
      attrs
      // (
        lib.mapAttrs'
        (user: v: {
          name = "${user}@${getFqdn c}";
          value = v.home;
        })
        c.config.home-manager.users
      );
    mkHmConfigs = lib.foldl op {};
  in
    mkHmConfigs (builtins.attrValues systemConfigurations);
}
