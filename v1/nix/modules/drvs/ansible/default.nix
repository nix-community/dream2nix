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

  public = {
    name = "ansible";
    version = "2.7.1";
  };

  mkDerivation = {

    preUnpack = ''
      export src=$(ls ${config.mach-nix.pythonSources}/names/${config.public.name}/*);
    '';
  };

  buildPythonPackage = {
    format = "setuptools";

    pythonImportsCheck = [
      config.public.name
    ];
  };

  mach-nix.pythonSources = config.deps.fetchPythonRequirements {
    inherit python;
    name = config.public.name;
    requirementsList = ["${config.public.name}==${config.public.version}"];
    hash = "sha256-OauI+N5IX1YEU9LnqZjgrvrR7RtrXXAza5VwLVpNkfw=";
    maxDate = "2023-01-01";
  };
}
