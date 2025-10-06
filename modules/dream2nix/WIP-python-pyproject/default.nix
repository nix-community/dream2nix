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
    pyproject = true;
  };

  inherit (pyproject.project) name;
  inherit (pyproject.project) version;

  pip.requirementsList = pyproject.project.dependencies;
  pip.flattenDependencies = true;
}
