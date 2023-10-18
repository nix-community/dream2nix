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

  lock_data = lib.importTOML config.pdm.lockfile;
  environ = libpyproject.pep508.mkEnviron config.deps.python3;
  selector = libpdm.preferWheelSelector;

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
    ../core/deps
    ./interface.nix
  ];
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      curl
      jq
      stdenvNoCC
      ;
  };
  commonModule = {
    options.sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
    config.sourceSelector = lib.mkOptionDefault config.pdm.sourceSelector;
  };
  groups = let
    populateGroup = groupname: deps: let
      deps' = libpdm.selectForGroup {
        inherit groupname parsed_lock_data groups_with_deps;
      };

      packages = lib.flip lib.mapAttrs deps' (name: pkg: {
        ${pkg.version} = {
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
              (depName: lib.head (lib.attrValues (config.groups.${groupname}.public.packages.${depName})));
          };
        };
      });
    in {inherit packages;};
  in
    lib.mapAttrs populateGroup groups_with_deps;
}
