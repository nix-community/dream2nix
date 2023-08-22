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

  ignored = l.genAttrs cfg.ignoredDependencies (name: true);

  filterTarget = target:
    l.filterAttrs (name: target: ! ignored ? ${name}) target;

  # filter out ignored dependencies
  targets = l.flip l.mapAttrs metadata.targets (
    targetName: target:
      l.flip l.mapAttrs (filterTarget target) (
        packageName: deps:
          l.filter (dep: ! ignored ? ${dep}) deps
      )
  );

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
        src = l.mkDefault (l.fetchurl {inherit (metadata.sources.${config.name}) url sha256;});
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
      propagatedBuildInputs =
        if cfg.flattenDependencies
        then
          if targets.default ? ${config.name}
          then
            throw ''
              Top-level package ${config.name} is listed in the lockfile.
              Set `pip.flattenDependencies` to false to use only the top-level dependencies.
            ''
          else let
            topLevelDepNames = l.attrNames (targets.default);
          in
            l.map (name: cfg.drvs.${name}.public.out) topLevelDepNames
        else if ! targets.default ? ${config.name}
        then
          throw ''
            Top-level package ${config.name} is not listed in the lockfile.
            Set `pip.flattenDependencies` to true to use all dependencies for the top-level package.
          ''
        else [];
    };
  };
}
