{config, ...}: let
  l = config.lib;
  inherit (config) pkgs externalSources;
in {
  config = {
    externals = {
      crane = let
        importLibFile = name: import "${externalSources.crane}/lib/${name}.nix";

        makeHook = attrs: name:
          pkgs.makeSetupHook
          ({inherit name;} // attrs)
          "${externalSources.crane}/lib/setupHooks/${name}.sh";
        genHooks = names: attrs: l.genAttrs names (makeHook attrs);
      in
        {
          cargoHostTarget,
          cargoBuildBuild,
        }: rec {
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
                zstd = "${pkgs.pkgsBuildBuild.zstd}/bin/zstd";
              };
            };
          installLogHook = genHooks ["installFromCargoBuildLogHook"] {
            substitutions = {
              cargo = "${cargoBuildBuild}/bin/cargo";
              jq = "${pkgs.pkgsBuildBuild.jq}/bin/jq";
            };
          };

          # These aren't used by dream2nix
          crateNameFromCargoToml = null;
          vendorCargoDeps = null;

          writeTOML = importLibFile "writeTOML" {
            inherit (pkgs) runCommand pkgsBuildBuild;
          };
          cleanCargoToml = importLibFile "cleanCargoToml" {};
          findCargoFiles = importLibFile "findCargoFiles" {
            inherit (pkgs) lib;
          };
          mkDummySrc = importLibFile "mkDummySrc" {
            inherit (pkgs) writeText runCommandLocal lib;
            inherit writeTOML cleanCargoToml findCargoFiles;
          };

          mkCargoDerivation = importLibFile "mkCargoDerivation" {
            cargo = cargoHostTarget;
            inherit (pkgs) stdenv zstd;
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
            inherit
              mkCargoDerivation
              crateNameFromCargoToml
              vendorCargoDeps
              mkDummySrc
              ;
          };
          buildPackage = importLibFile "buildPackage" {
            inherit (pkgs) lib jq;
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
    };
  };
}
