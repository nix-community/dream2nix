{
  dream2nix,
  config,
  lib,
  ...
}: let
  pyproject =
    builtins.fromTOML
    (builtins.readFile (config.mkDerivation.src + /pyproject.toml));
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  mkDerivation = {
    buildInputs =
      pyproject.build-system.requires
      or [config.deps.python.pkgs.setuptools];
  };

  buildPythonPackage = {
    format = "pyproject";
    pythonImportsCheck = pyproject.tool.setuptools.packages.find.include or [];
  };

  name = pyproject.project.name;
  version = pyproject.project.version;

  pip.requirementsList = pyproject.project.dependencies;
  pip.flattenDependencies = true;
}
