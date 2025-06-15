{self, ...}: {
  perSystem = {
    pkgs,
    inputs',
    lib,
    ...
  }: let
    inherit
      (lib)
      elem
      filterAttrs
      mapAttrsToList
      hasPrefix
      ;
    isWip = hasPrefix "WIP-";
    doRender = name: ! elem name ignore;
    wipModules = filterAttrs (name: _: isWip name && doRender name) self.modules.dream2nix;
    normalModules = filterAttrs (name: _: ! isWip name && doRender name) self.modules.dream2nix;
    ignore = [
      "assertions"
    ];
    mkScope = name: module: {
      inherit name;
      modules = [module];
      urlPrefix = "https://github.com/nix-community/dream2nix/blob/main/";
      specialArgs = {
        dream2nix.modules = self.modules;
      };
    };
  in {
    packages.website-options = inputs'.nuschtos.packages.mkMultiSearch {
      baseHref = "/options/";
      title = "dream2nix modules";
      scopes =
        mapAttrsToList mkScope normalModules
        ++ mapAttrsToList mkScope wipModules;
    };
  };
}
