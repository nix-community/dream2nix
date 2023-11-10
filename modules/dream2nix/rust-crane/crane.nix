{
  lib,
  craneSource,
  # nixpkgs
  cargo,
  makeSetupHook,
  runCommand,
  writeText,
  stdenv,
  zstd,
  jq,
  remarshal,
  darwin,
}: let
  importLibFile = name: import "${craneSource}/lib/${name}.nix";

  makeHook = attrs: name:
    makeSetupHook
    ({inherit name;} // attrs)
    "${craneSource}/lib/setupHooks/${name}.sh";
  genHooks = names: attrs: lib.genAttrs names (makeHook attrs);

  crane = rec {
    dummyHook = makeSetupHook {name = "dummyHook";} (writeText "dummyHook.sh" ":");
    otherHooks =
      genHooks [
        "cargoHelperFunctionsHook"
        "configureCargoCommonVarsHook"
        "configureCargoVendoredDepsHook"
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
    removeReferencesHook = import "${craneSource}/lib/setupHooks/removeReferencesToVendoredSources.nix" {
      inherit lib makeSetupHook stdenv;
      pkgsBuildBuild = {inherit darwin;};
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
      inherit writeText runCommand lib;
      inherit writeTOML cleanCargoToml findCargoFiles;
    };

    mkCargoDerivation = importLibFile "mkCargoDerivation" {
      inherit stdenv zstd cargo lib writeText writeTOML;
      # the code path that triggers rsync doesn't get used in dream2nix
      rsync = zstd;
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
      # this hook doesn't matter in our case because we want to do this ourselves in d2n
      replaceCargoLockHook = dummyHook;
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
      removeReferencesToVendoredSourcesHook = removeReferencesHook;
    };
  };
in {
  inherit (crane) buildPackage buildDepsOnly;
}
