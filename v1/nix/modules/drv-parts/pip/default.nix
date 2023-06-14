{
  config,
  lib,
  dream2nix,
  ...
} @ topLevel: let
  l = lib // builtins;
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

  depNamesTopLevel =
    l.attrNames
    (l.removeAttrs config.lock.content.fetchPipMetadata [config.name]);

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
      ../nixpkgs-overrides
    ];
    config = {
      inherit name version;
    };
  };

  commonModule = {config, ...}: let
    depNames =
      metadata.${config.name}.dependencies
      ++ (
        l.optionals (config.name == topLevel.config.name)
        depNamesTopLevel
      );
  in {
    imports = [
      dream2nix.modules.drv-parts.mkDerivation
      ../buildPythonPackage
    ];
    config = {
      deps = {nixpkgs, ...}:
        l.mapAttrs (_: l.mkDefault) {
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
          l.map (name: cfg.drvs.${name}.public.out) depNames;
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
