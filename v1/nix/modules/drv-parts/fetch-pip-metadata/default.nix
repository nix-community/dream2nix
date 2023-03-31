{
  config,
  lib,
  drv-parts,
  name,
  version,
  ...
}: let
  l = lib // builtins;

  fetchPip = import ../../../pkgs/fetchPipMetadata {
    inherit lib;
    inherit
      (config.deps)
      buildPackages
      stdenv
      python3 # only used for proxy script
      ;
  };
in {
  imports = [
    ./interface.nix
    ../lock
    drv-parts.modules.drv-parts.mkDerivation
  ];

  inherit name version;

  package-func.outputs = ["out"];

  deps = {nixpkgs, ...}:
    l.mapAttrs (_: l.mkDefault) {
      inherit
        (nixpkgs)
        buildPackages
        stdenv
        python3 # only used for proxy script
        ;
      python = nixpkgs.python3;
    };

  package-func.func = fetchPip;
  package-func.args = l.mkForce (
    config.fetch-pip-metadata
    // {
      inherit (config) name;
    }
    // lib.optionalAttrs (config.mkDerivation.nativeBuildInputs != null) {
      inherit (config.mkDerivation) nativeBuildInputs;
    }
  );
}
