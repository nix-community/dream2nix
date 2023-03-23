{
  config,
  lib,
  drv-parts,
  name,
  version,
  ...
}: let
  l = lib // builtins;

  fetchPip = import ../../../pkgs/fetchPip {
    inherit lib;
    inherit
      (config.deps)
      buildPackages
      stdenv
      ;
  };
in {
  imports = [
    ./interface.nix
    drv-parts.modules.drv-parts.mkDerivation
  ];

  inherit name version;

  package-func.outputs = ["out" "names"];

  deps = {nixpkgs, ...}:
    l.mapAttrs (_: l.mkDefault) {
      inherit
        (nixpkgs)
        buildPackages
        stdenv
        ;
      python = nixpkgs.python3;
    };

  package-func.func = fetchPip;
  package-func.args = l.mkForce (
    config.fetch-pip
    // {
      inherit (config) name;
    }
  );
}
