{
  config,
  lib,
  dream2nix,
  pyproject-nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.pex;
  python = config.deps.python;
  pyproject = config.deps.pyproject-nix;

  pep425 = import ./pep425.nix {
    inherit lib;
    inherit (config.deps) stdenv python;
    inherit (pyproject) pep599;
  };

  mkModule = package: {config, ...}: {
    imports = [
      dream2nix.modules.drv-parts.mkDerivation
      dream2nix.modules.drv-parts.buildPythonPackage
    ];

    config = {
      deps = {nixpkgs, ...}:
        l.mapAttrs (_: l.mkDefault) {
          inherit
            (nixpkgs)
            autoPatchelfHook
            stdenv
            fetchurl
            ;
          inherit (nixpkgs.pythonManylinuxPackages) manylinux1;
        };

      inherit
        (package)
        name
        version
        ;

      mkDerivation.src = config.deps.fetchurl {
        url = package.source.file;
        sha256 = package.source.hash;
      };

      mkDerivation.propagatedBuildInputs = l.map (dep: cfg.packages.${dep}.public.out) package.requirements;

      mkDerivation.nativeBuildInputs =
        l.optionals config.deps.stdenv.isLinux [config.deps.autoPatchelfHook];
      mkDerivation.buildInputs =
        l.optionals config.deps.stdenv.isLinux [config.deps.manylinux1];

      # FIXME probably unnecessary with pypaBuildHook, or with build-system.requires in lock
      buildPythonPackage.format = l.mkDefault (
        if l.hasSuffix ".whl" config.mkDerivation.src
        then "wheel"
        else "pyproject"
      );
    };
  };
in {
  imports = [
    dream2nix.modules.drv-parts.core
    dream2nix.modules.drv-parts.writers
    ./interface.nix
  ];

  config = {
    deps = {
      nixpkgs,
      pyproject-nix,
      ...
    }:
      l.mapAttrs (_: l.mkDefault) {
        pex = config.deps.python.pkgs.pex;
        inherit (nixpkgs) git stdenv bash;
        python = nixpkgs.python3;
        inherit pyproject-nix;
      };

    lock = {
      fields.pex = {
        script =
          config.writers.writePureShellScript [config.deps.python]
          ''
            set -x
            PEX_VERBOSE=9 \
              ${config.deps.pex}/bin/pex3 \
              lock create \
              --pip-version ${cfg.pipVersion} \
              --style universal \
              --target-system mac \
              --target-system linux \
              --use-pep517 \
              ${lib.escapeShellArgs cfg.requirementsList} \
              --indent 2 \
              -o $out
          '';
      };
    };

    pex = {
      lib = import ./lib.nix {
        inherit lib;
        inherit pep425;
        inherit (pyproject) pep508 pypa;
      };
      packages = l.mapAttrs (n: v: mkModule v) (cfg.lib.packagesFromLockField
        cfg.environ
        cfg.extras
        config.lock.content.pex);
    };
  };
}
