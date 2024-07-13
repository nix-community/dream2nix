{
  config,
  lib,
  dream2nix,
  ...
}: let
  src = config.deps.fetchFromGitHub {
    owner = "odoo";
    repo = "odoo";
    # ref: 16.0
    rev = "2d42fd69cada3b1f2716c3d0a20bec6170f9b226";
    hash = "sha256-ZlPH+RaRZbWooe+kpiFYZtvuVmXtOMHeCW+Z74ZscXY=";
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
    python = nixpkgs.python39;
  };

  name = "odoo";
  version = "16.0";

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
    nativeBuildInputs = [config.deps.postgresql];

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
