# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: let
  pyproject = lib.importTOML (config.mkDerivation.src + /pyproject.toml);
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
    propagatedBuildInputs = [
      config.pip.drvs.setuptools.public
    ];
  };

  buildPythonPackage = {
    pyproject = true;
    pythonImportsCheck = [
      "my_tool"
    ];
  };

  pip = {
    requirementsList =
      pyproject.build-system.requires
      or []
      ++ pyproject.project.dependencies;
    flattenDependencies = true;
  };
}
