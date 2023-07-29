{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  cfg = config.pip;
  python = config.deps.python;
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
    metadata.sources;

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
      # deps.python cannot be defined in commonModule as this would trigger an
      #   infinite recursion.
      deps = {inherit python;};
    };
  };

  commonModule = {config, ...}: {
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
        src = l.mkDefault (l.fetchurl {inherit (metadata.sources.${config.name}) url sha256;});
        doCheck = l.mkDefault false;

        nativeBuildInputs =
          l.optionals config.deps.stdenv.isLinux [config.deps.autoPatchelfHook];
        buildInputs =
          l.optionals config.deps.stdenv.isLinux [config.deps.manylinux1];
        propagatedBuildInputs = let
          depsByExtra = extra: metadata.targets.${extra}.${config.name} or [];
          defaultDeps = metadata.targets.default.${config.name} or [];
          deps = defaultDeps ++ (l.concatLists (l.map depsByExtra cfg.buildExtras));
        in
          l.map (name: cfg.drvs.${name}.public.out) deps;
      };
    };
  };
in {
  imports = [
    commonModule
    ./interface.nix
  ];

  config = {
    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        fetchPipMetadataScript = nixpkgs.callPackage ../../../pkgs/fetchPipMetadata {
          inherit (cfg) pypiSnapshotDate pipFlags pipVersion requirementsList requirementsFiles nativeBuildInputs;
          inherit (config.deps) writePureShellScript python nix git;
        };
        setuptools = config.deps.python.pkgs.setuptools;
        inherit (nixpkgs) git;
        inherit (writers) writePureShellScript;
      };

    # Keep package metadata fetched by Pip in our lockfile
    lock.fields.fetchPipMetadata = {
      script = config.deps.fetchPipMetadataScript;
    };

    pip = {
      drvs = drvs;
    };

    mkDerivation = {
      dontStrip = l.mkDefault true;
    };
  };
}
