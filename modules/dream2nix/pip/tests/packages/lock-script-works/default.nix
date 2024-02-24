# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  packageSets,
  ...
}: let
  pyproject = lib.importTOML (config.mkDerivation.src + /pyproject.toml);
  pkgs = packageSets.nixpkgs;
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python310;
  };

  inherit (pyproject.project) name version;

  mkDerivation = {
    src = ./.;
  };

  pip = {
    pypiSnapshotDate = "2023-08-27";
    requirementsList =
      pyproject.build-system.requires
      or []
      ++ pyproject.project.dependencies;
    flattenDependencies = true;
  };

  paths.projectRootFile = "pyproject.toml";

  public = lib.mkForce (pkgs.runCommand "pip-lock-script-works" {
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = "sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=";
      # invalidate by including into the name a hash over:
      # - the path to the nixpkgs
      # - TODO: the implementation of the fetch script
      name = let
        hash = builtins.hashString "sha256" (builtins.unsafeDiscardStringContext ''
          ${pkgs.path}
        '');
      in "pip-lock-script-works-${lib.substring 0 16 hash}";
    } ''
      cp -r ${config.mkDerivation.src}/* .
      chmod +w -R .
      ls -lah
      ${config.lock.refresh}/bin/refresh
      touch $out
    '');
}
