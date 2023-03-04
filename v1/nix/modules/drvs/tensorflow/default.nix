{config, lib, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs)
      postgresql
      fetchFromGitHub
      ;
  };

  env.format = "wheel";

  env.pythonImportsCheck = [
    config.mkDerivation.pname
  ];

  mkDerivation = {
    pname = "tensorflow";
    version = "2.11.0";

    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.mkDerivation.pname}/*);
    '';
  };

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.mkDerivation.pname;
    requirementsList = ["${config.mkDerivation.pname}==${config.mkDerivation.version}"];
    hash = "sha256-hnUe+iED9Q/6MjrDIHR8dNDUMZGPl+KBhHRs4NOnk88=";
    maxDate = "2023-01-01";
  };
}
