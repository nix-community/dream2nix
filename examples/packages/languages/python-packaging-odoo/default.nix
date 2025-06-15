{
  config,
  lib,
  dream2nix,
  ...
}: let
  src = config.deps.fetchFromGitHub {
    owner = "odoo";
    repo = "odoo";
    # version 18.0
    # Don't use tag as rev. It changes a lot
    rev = "f8c4250d71a74c9228eaa61abcfdb123c8cd3460";
    hash = "sha256-HAdfwhSkSrFRK/klKgnaqvI69RrFFT5h1SNEEYqoack=";
  };
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
    python = nixpkgs.python311;
  };

  name = "odoo";
  version = "18.0";

  mkDerivation = {
    inherit src;
  };

  paths.lockFile = "lock.${config.deps.stdenv.system}.json";
  pip = {
    requirementsList = [
      "${src}"
    ];

    # These buildInputs are only used during locking, well-behaved, i.e.
    # PEP 518 packages should not those, but some packages like psycopg2
    # require dependencies to be available during locking in order to execute
    # setup.py. This is fixed in psycopg3
    nativeBuildInputs = [config.deps.postgresql.pg_config];

    # fix some builds via package-specific overrides
    overrides = {
      psycopg2 = {
        imports = [
          dream2nix.modules.dream2nix.nixpkgs-overrides
        ];
        # We can bulk-inherit overrides from nixpkgs, to which often helps to
        # get something working quickly. In this case it's needed for psycopg2
        # to build on aarch64-darwin. We exclude propagatedBuildInputs to keep
        # python deps from our lock file and avoid version conflicts
        nixpkgs-overrides = {
          exclude = ["propagatedBuildInputs"];
        };
        # packages-specific build inputs that are used for this
        # package only. Included here for demonstration
        # purposes, as nativeBuildInputs from nixpkgs-overrides
        # should already include it
        mkDerivation.nativeBuildInputs = [config.deps.postgresql];
      };
      libsass.mkDerivation = {
        doCheck = false;
        doInstallCheck = lib.mkForce false;
      };
      pypdf2.mkDerivation = {
        doCheck = false;
        doInstallCheck = lib.mkForce false;
      };
    };
  };
}
