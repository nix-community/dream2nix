{
  lib,
  craneSource,
  # nixpkgs
  cargo,
  makeSetupHook,
  runCommand,
  runCommandLocal,
  writeText,
  stdenv,
  zstd,
  jq,
  remarshal,
}: let
  importLibFile = name: import "${craneSource}/lib/${name}.nix";

  makeHook = attrs: name:
    makeSetupHook
    ({inherit name;} // attrs)
    "${craneSource}/lib/setupHooks/${name}.sh";
  genHooks = names: attrs: lib.genAttrs names (makeHook attrs);

  crane = rec {
    otherHooks =
      genHooks [
        "cargoHelperFunctionsHook"
        "configureCargoCommonVarsHook"
        "configureCargoVendoredDepsHook"
        "removeReferencesToVendoredSourcesHook"
      ]
      {};
    installHooks =
      genHooks [
        "inheritCargoArtifactsHook"
        "installCargoArtifactsHook"
      ]
      {
        substitutions = {
          zstd = "${zstd}/bin/zstd";
        };
      };
    installLogHook = genHooks ["installFromCargoBuildLogHook"] {
      substitutions = {
        cargo = "${cargo}/bin/cargo";
        jq = "${jq}/bin/jq";
      };
    };

    # These aren't used by dream2nix
    crateNameFromCargoToml = null;
    vendorCargoDeps = null;

    writeTOML = importLibFile "writeTOML" {
      inherit runCommand;
      pkgsBuildBuild = {inherit remarshal;};
    };
    cleanCargoToml = importLibFile "cleanCargoToml" {};
    findCargoFiles = importLibFile "findCargoFiles" {
      inherit lib;
    };
    mkDummySrc = importLibFile "mkDummySrc" {
      inherit writeText runCommandLocal lib;
      inherit writeTOML cleanCargoToml findCargoFiles;
    };

    mkCargoDerivation = importLibFile "mkCargoDerivation" {
      inherit stdenv zstd cargo;
      inherit
        (installHooks)
        inheritCargoArtifactsHook
        installCargoArtifactsHook
        ;
      inherit
        (otherHooks)
        configureCargoCommonVarsHook
        configureCargoVendoredDepsHook
        cargoHelperFunctionsHook
        ;
      inherit crateNameFromCargoToml vendorCargoDeps;
    };
    buildDepsOnly = importLibFile "buildDepsOnly" {
      inherit lib;
      inherit
        mkCargoDerivation
        crateNameFromCargoToml
        vendorCargoDeps
        mkDummySrc
        ;
    };
    buildPackage = importLibFile "buildPackage" {
      inherit lib jq;
      inherit (installLogHook) installFromCargoBuildLogHook;
      inherit
        buildDepsOnly
        crateNameFromCargoToml
        vendorCargoDeps
        mkCargoDerivation
        ;
      inherit (otherHooks) removeReferencesToVendoredSourcesHook;
    };
  };
in {
  inherit (crane) buildPackage buildDepsOnly;
}
