# TODO replace former manualSetupDeps with PEP 518 impl
{
  config,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;
  python = config.deps.python;
  cfg = config.buildPythonEnv;
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
        doCheck = l.mkDefault true;

        nativeBuildInputs = [config.deps.autoPatchelfHook];
        buildInputs = [config.deps.manylinux1];
        propagatedBuildInputs =
          l.map (name: cfg.drvs.${name}.public.out)
          metadata.${config.name}.dependencies;
        # ensure build inputs are propagated for autopPatchelfHook
        postFixup = "ln -s $out $dist/out";
      };
    };
  };

  # Validate Substitutions. Allow only names that we actually depend on.
  unknownSubstitutions = l.attrNames (l.removeAttrs cfg.substitutions (l.attrNames metadata));
  substitutions =
    if unknownSubstitutions == []
    then cfg.substitutions
    else
      throw ''
        ${"\n"}The following substitutions for python derivation '${packageName}' will not have any effect. There are no dependencies with such names:
        - ${lib.concatStringsSep "\n  - " unknownSubstitutions}
      '';
  # Usually references to buildInputs would get lost in the dist output.
  # Patch wheels to ensure build inputs remain dependencies of the `dist` output
  # Those references are needed for the final autoPatchelfHook to find the required deps.
  patchedSubstitutions = l.mapAttrs (name: drv:
    drv-parts.lib.makeModule {
      packageFunc = drv.overridePythonAttrs (old: {postFixup = "ln -s $out $dist/out";});
      # TODO: if `overridePythonAttrs` is used here, the .dist output is missing
      #   Maybe a bug in drv-parts?
      #      overrideFuncName = "overrideAttrs";
      modules = [
        {deps = {inherit (config.deps) stdenv;};}
      ];
    })
  substitutions;
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
        runCommand = nixpkgs.runCommand;
        pip = nixpkgs.python3Packages.pip;
        setuptools = nixpkgs.python3Packages.setuptools;
      };

    # Keep package metadata fetched by Pip in our lockfile
    lock.fields.fetchPipMetadata = {
      script = config.deps.fetchPipMetadata {
        inherit (cfg) pypiSnapshotDate pipFlags requirementsList requirementsFiles nativeBuildInputs;
        inherit (config.deps) python;
      };
      default = {};
    };

    buildPythonEnv = {
      # TODO: substitutions might lead to conflicts due to duplicated dependencies. We'd probably
      # need to substitute each given package *and* its transistive dependencies.
      drvs = drvs // patchedSubstitutions;
    };

    mkDerivation = {
      dontPatchELF = l.mkDefault true;
      dontStrip = l.mkDefault true;

      passthru = {
        # The final dists we want to install.
        # A mix of:
        #   - downloaded wheels
        #   - downloaded sdists built into wheels (see above)
        #   - substitutions from nixpkgs patched for compat with autoPatchelfHook
        # TODO still useful? rename to "wheels"?
        dists = l.mapAttrs (_: drv: drv.public.out.dist) config.buildPythonEnv.drvs;
      };
    };
  };
}
