{config, lib, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ../../drv-parts/mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python39;
  };

  pname = "ansible";
  version = "2.7.1";

  env.format = "setuptools";

  env.pythonImportsCheck = [
    config.pname
  ];

  preUnpack = ''
    export src=$(ls ${config.mach-nix.pythonSources}/names/${config.pname}/*);
  '';

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit python;
    name = config.pname;
    requirementsList = ["${config.pname}==${config.version}"];
    hash = "sha256-Wdu4A9nFfVhHwj2rYrhb6A5xtZ2VytEc4F8Bo6kgFtg=";
    maxDate = "2023-01-01";
  };
}
