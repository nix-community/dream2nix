{
  config,
  lib,
  dream2nix,
  ...
}: let
  libpdm = import ./lib.nix {
    inherit lib libpyproject;
  };

  libpyproject = import (dream2nix.inputs.pyproject-nix + "/lib") {inherit lib;};

  selectWheel = import ../../../lib/internal/python/selectWheel.nix {
    inherit lib;
    pep599 = libpyproject.pep599;
    python = config.deps.python3;
    stdenv = config.deps.stdenv;
  };

  lock_data = lib.importTOML config.pdm.lockfile;
  environ = libpyproject.pep508.mkEnviron config.deps.python3;
  selector = config.pdm.sourceSelector;

  pyproject = libpdm.loadPdmPyProject (lib.importTOML config.pdm.pyproject);

  groups_with_deps = libpdm.groupsWithDeps {
    inherit environ pyproject;
  };
  parsed_lock_data = libpdm.parseLockData {
    inherit environ lock_data selector;
  };

  fetchFromPypi = import ./fetch-from-pypi.nix {
    inherit lib;
    inherit (config.deps) curl jq stdenvNoCC;
  };
in {
  imports = [
    dream2nix.modules.dream2nix.groups
    dream2nix.modules.dream2nix.buildPythonPackage
    ../core/deps
    ./interface.nix
  ];
  name = pyproject.pyproject.project.name;
  version = pyproject.pyproject.project.version;
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      curl
      jq
      stdenvNoCC
      stdenv
      ;
  };
  pdm.sourceSelector = lib.mkDefault selectWheel;
  commonModule = {
    options.sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
    # TODO: per dependency selector isn't yet respected
    config.sourceSelector = lib.mkOptionDefault config.pdm.sourceSelector;
  };
  buildPythonPackage = {
    format = "pyproject";
  };
  mkDerivation = {
    propagatedBuildInputs =
      map
      (x: (lib.head (lib.attrValues x)).public)
      # all packages attrs prefixed with version
      (lib.attrValues config.groups.default.packages);
  };
  groups = let
    populateGroup = groupname: deps: let
      deps' = libpdm.selectForGroup {
        inherit groupname parsed_lock_data groups_with_deps;
      };

      packages = lib.flip lib.mapAttrs deps' (name: pkg: {
        ${pkg.version}.conf = {
          inherit name;
          version = pkg.version;
          imports = [
            dream2nix.modules.dream2nix.buildPythonPackage
            dream2nix.modules.dream2nix.mkDerivation
            dream2nix.modules.dream2nix.package-func
          ];
          buildPythonPackage = {
            format =
              if lib.hasSuffix ".whl" pkg.source.file
              then "wheel"
              else "pyproject";
          };
          mkDerivation = {
            # required: { pname, file, version, hash, kind, curlOpts ? "" }:
            src = fetchFromPypi {
              pname = name;
              file = pkg.source.file;
              version = pkg.version;
              hash = pkg.source.hash;
              kind = "";
            };
            propagatedBuildInputs =
              lib.forEach
              parsed_lock_data.${name}.dependencies
              (depName: (lib.head (lib.attrValues (config.groups.${groupname}.packages.${depName}))).public);
          };
        };
      });
    in {inherit packages;};
  in
    lib.mapAttrs populateGroup groups_with_deps;
}
