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

  # filter out ignored dependencies
  targets = cfg.targets;

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

  fetchers = {
    url = info: l.fetchurl {inherit (info) url sha256;};
    git = info: config.deps.fetchgit {inherit (info) url sha256 rev;};
  };

  commonModule = {config, ...}: {
    imports = [
      dream2nix.modules.dream2nix.mkDerivation
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
            unzip
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
        src = l.mkDefault (fetchers.${metadata.sources.${config.name}.type} metadata.sources.${config.name});
        doCheck = l.mkDefault false;

        nativeBuildInputs =
          [config.deps.unzip]
          ++ (l.optionals config.deps.stdenv.isLinux [config.deps.autoPatchelfHook]);
        buildInputs =
          l.optionals config.deps.stdenv.isLinux [config.deps.manylinux1];
        propagatedBuildInputs = let
          depsByExtra = extra: targets.${extra}.${config.name} or [];
          defaultDeps = targets.default.${config.name} or [];
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
    ../pip-hotfixes
  ];

  config = {
    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        fetchPipMetadataScript = nixpkgs.callPackage ../../../pkgs/fetchPipMetadata {
          inherit (cfg) pypiSnapshotDate pipFlags pipVersion requirementsList requirementsFiles nativeBuildInputs;
          inherit (config.deps) writePureShellScript python nix git;
        };
        setuptools = config.deps.python.pkgs.setuptools;
        inherit (nixpkgs) git fetchgit;
        inherit (writers) writePureShellScript;
      };

    # Keep package metadata fetched by Pip in our lockfile
    lock.fields.fetchPipMetadata = {
      script = config.deps.fetchPipMetadataScript;
    };

    pip = {
      drvs = drvs;
      rootDependencies =
        l.genAttrs (targets.default.${config.name} or []) (_: true);
    };

    mkDerivation = {
      dontStrip = l.mkDefault true;
      propagatedBuildInputs = let
        rootDeps = lib.filterAttrs (_: x: x == true) cfg.rootDependencies;
      in
        l.attrValues (l.mapAttrs (name: _: cfg.drvs.${name}.public.out) rootDeps);
    };
  };
}
