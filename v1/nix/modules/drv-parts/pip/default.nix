{
  config,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  cfg = config.pip;
  packageName = config.name;
  metadata = config.lock.content.fetchPipMetadata;

  drvs =
    l.mapAttrs (
      name: info:
        buildDependency {
          inherit name;
          inherit (info) version;
        }
    )
    metadata;

  buildDependency = {
    name,
    version,
  }: {config, ...}: {
    imports = [
      commonModule
    ];
    config = {
      inherit name version;
    };
  };

  commonModule = {config, ...}: {
    imports = [
      drv-parts.modules.drv-parts.mkDerivation
      ../buildPythonPackage
      ../nixpkgs-overrides
    ];
    config = {
      deps = {nixpkgs, ...}:
        l.mapAttrs (_: l.mkDefault) {
          inherit python;
          inherit
            (nixpkgs)
            autoPatchelfHook
            stdenv
            ;
          inherit (nixpkgs.pythonManylinuxPackages) manylinux1;
        };
      buildPythonPackage = {
        format = l.mkDefault (
          if l.hasSuffix ".whl" config.mkDerivation.src
          then "wheel"
          else "setuptools"
        );
      };
      mkDerivation = {
        src = l.mkDefault (l.fetchurl {inherit (metadata.${config.name}) url sha256;});
        doCheck = l.mkDefault false;

        nativeBuildInputs = [config.deps.autoPatchelfHook];
        buildInputs = [config.deps.manylinux1];
        propagatedBuildInputs =
          l.map (name: cfg.drvs.${name}.public.out)
          metadata.${config.name}.dependencies;
      };
    };
  };
in {
  imports = [
    commonModule
    ./interface.nix
    ../lock
  ];

  config = {
    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        fetchPipMetadata = nixpkgs.callPackage ../../../pkgs/fetchPipMetadata {};
        setuptools = nixpkgs.python3Packages.setuptools;
        inherit (nixpkgs) git;
      };

    # Keep package metadata fetched by Pip in our lockfile
    lock.fields.fetchPipMetadata = {
      script = config.deps.fetchPipMetadata {
        inherit (cfg) pypiSnapshotDate pipFlags pipVersion requirementsList requirementsFiles nativeBuildInputs;
        inherit (config.deps) python nix git;
      };
    };

    pip = {
      drvs = drvs;
    };

    mkDerivation = {
      dontStrip = l.mkDefault true;
    };
  };
}
