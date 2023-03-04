{config, lib, drv-parts, ...}: {

  # import the drv-parts core
  imports = [drv-parts.modules.drv-parts.core];

  # provide options for buildPythonPackage
  options.buildPythonPackage = lib.mkOption {
    type = with lib.types; attrsOf anything;
    default = {};
  };

  # pass options for buildPythonPackage to the final function call
  config.package-func.args = config.buildPythonPackage;

  # set nixpkgs.buildPythonPackage as the final package function
  config.package-func.func = config.deps.python.pkgs.buildPythonPackage;
}
