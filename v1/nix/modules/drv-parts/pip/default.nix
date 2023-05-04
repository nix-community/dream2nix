{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  cfg = config.pip;
  metadata = config.lock.content.fetchPipMetadata;

  writers = import ../../../pkgs/writers {
    inherit lib;
    inherit
      (config.deps)
      bash
      coreutils
      gawk
      path
      writeScript
      writeScriptBin
      ;
  };

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
      dream2nix.modules.drv-parts.mkDerivation
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
            bash
            coreutils
            gawk
            path
            stdenv
            writeScript
            writeScriptBin
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

        nativeBuildInputs =
          l.optionals config.deps.stdenv.isLinux [config.deps.autoPatchelfHook];
        buildInputs =
          l.optionals config.deps.stdenv.isLinux [config.deps.manylinux1];
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
        inherit (writers) writePureShellScript;
      };

    # Keep package metadata fetched by Pip in our lockfile
    lock.fields.fetchPipMetadata = {
      script = config.deps.fetchPipMetadata {
        inherit (cfg) pypiSnapshotDate pipFlags pipVersion requirementsList requirementsFiles nativeBuildInputs;
        inherit (config.deps) writePureShellScript python nix git;
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
