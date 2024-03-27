{
  config,
  lib,
  dream2nix,
  ...
}: let
  python = config.deps.python;
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python310;
  };

  name = "hello";
  version = "1.0";

  mkDerivation = {
    src = ./.;
  };

  pip = {
    pypiSnapshotDate = "2023-11-11";
    requirementsList = [
      "cryptography"
    ];

    # Required to be true because lockfile does not contain the hello package
    # It only contains our requirement "cryptography"
    flattenDependencies = true;
  };
}
