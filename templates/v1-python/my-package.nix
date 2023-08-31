{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  name = "my-package";
  version = "1.0";

  mkDerivation = {
    src = ./.;
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      postgresql
      stdenv
      ;
    python = nixpkgs.python310;
  };

  buildPythonPackage = {
    format = "pyproject";
  };

  pip = {
    pypiSnapshotDate = "2023-05-03";

    # pass the current directory as a requirement to pip which will then resolve
    #   all other requirements via the `dependencies` from pyproject.toml.
    requirementsList = ["."];

    # creating the lock file otherwise fails on psycopg2
    nativeBuildInputs = [config.deps.postgresql];

    # fix some builds via overrides
    drvs = {
      psycopg2.mkDerivation = {
        nativeBuildInputs = [config.deps.postgresql];
      };
    };
  };
}
