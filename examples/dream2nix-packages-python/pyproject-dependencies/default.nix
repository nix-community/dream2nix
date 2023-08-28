# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  pyproject = lib.pipe (config.mkDerivation.src + /pyproject.toml) [
    builtins.readFile
    builtins.fromTOML
  ];
in {
  imports = [
    dream2nix.modules.drv-parts.pip
  ];

  name = "pyproject-dependencies";
  version = pyproject.project.version;

  mkDerivation = {
    src = ./.;
  };

  buildPythonPackage = {
    format = lib.mkForce "pyproject";
    pythonImportsCheck = [
      "my_tool"
    ];
  };

  pip = {
    pypiSnapshotDate = "2023-08-27";
    requirementsList = ["setuptools"] ++ pyproject.project.dependencies;
    flattenDependencies = true;
  };
}
