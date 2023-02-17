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

  pname = "tensorflow";
  version = "2.11.0";

  env.format = "wheel";

  env.pythonImportsCheck = [
    config.pname
  ];

  preUnpack = ''
    export src=$(ls ${config.pythonSources}/names/${config.pname}/*);
  '';

  pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    name = config.pname;
    requirementsList = ["${config.pname}==${config.version}"];
    hash = "sha256-x5LpkZxs4McZFoyGCXtvHJo0RxIHdCWRoWmZ9Q3tqTw=";
    maxDate = "2023-01-01";
  };
}
