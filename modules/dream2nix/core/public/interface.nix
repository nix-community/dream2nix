{
  config,
  lib,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  opts = let
    optsPackage = import ./optsPackage.nix {
      inherit lib;
      inherit (config) outputs;
    };
    optsPackageCompat = import ./optsPackageCompat.nix {inherit lib;};
    optsPackageDrvParts = import ./optsPackageDrvParts.nix {inherit lib;};
  in
    optsPackage // optsPackageCompat // optsPackageDrvParts;

  opts' = l.flip l.mapAttrs opts (name: opt: opt // {internal = true;});
in {
  # this will contain the resulting derivation
  options.public = l.mkOption {
    type = t.submodule {
      freeformType = t.lazyAttrsOf t.anything;
      options = opts';
    };
    description = ''
      The final result of the evaluated package.
      Contains everything that nix expects from a derivation.
      Contains fields like name, outputs, drvPath, outPath, etc.
    '';
  };
}
